import NIOHTTPServer
import NIOCore
import NIOConcurrencyHelpers
import Logging

/// Adapts `NIOHTTPServer` to Vapor's `Server` protocol.
///
/// `NIOHTTPServer.serve()` is a blocking structured-concurrency call.
/// This adapter launches it in an unstructured `Task` from `start()` and
/// cancels that task from `shutdown()` as a workaround until Vapor's
/// server lifecycle is refactored to use structured concurrency.
final class NIOHTTPServerAdapter: Server, Sendable {
    let application: Application
    private let serveTask: NIOLockedValueBox<Task<Void, any Error>?>
    private let server: NIOLockedValueBox<NIOHTTPServer?>

    init(application: Application) {
        self.application = application
        self.serveTask = .init(nil)
        self.server = .init(nil)
    }

    func start() async throws {
        let (hostname, port) = self.resolveBindAddress()

        let configuration = try NIOHTTPServerConfiguration(
            bindTarget: .hostAndPort(host: hostname, port: port),
            supportedHTTPVersions: [.http1_1],
            transportSecurity: .plaintext
        )

        let nioServer = NIOHTTPServer(
            logger: self.application.logger,
            configuration: configuration
        )
        self.server.withLockedValue { $0 = nioServer }

        let responder: any Responder
        switch self.application.responder {
        case .default:
            responder = DefaultResponder(
                routes: self.application.routes,
                middleware: self.application.middleware.resolve(),
                reportMetrics: self.application.serverConfiguration.reportMetrics
            )
        case .provided(let provided):
            responder = provided
        }

        let handler = VaporHTTPServerHandler(
            application: self.application,
            responder: responder
        )

        // Launch serve() in an unstructured task so start() can return
        let task = Task {
            try await nioServer.serve(handler: handler)
        }
        self.serveTask.withLockedValue { $0 = task }

        // Wait for the listening address to become available and store it
        let address = try await nioServer.listeningAddress
        self.application.sharedNewAddress.withLockedValue {
            $0 = try? NIOCore.SocketAddress(ipAddress: address.host, port: address.port)
        }
        self.application.logger.notice("Server started on \(address.host):\(address.port)")
    }

    func shutdown() async throws {
        if let task = self.serveTask.withLockedValue({ $0 }) {
            task.cancel()
            // Wait for the serve task to finish
            try? await task.value
            self.serveTask.withLockedValue { $0 = nil }
        }
        self.server.withLockedValue { $0 = nil }
    }

    private func resolveBindAddress() -> (String, Int) {
        switch self.application.serverConfiguration.address {
        case .hostname(let hostname, let port):
            return (hostname, port)
        case .unixDomainSocket:
            self.application.logger.warning("Unix domain sockets are not supported by NIOHTTPServer. Falling back to default address.")
            return ("127.0.0.1", 8080)
        }
    }
}
