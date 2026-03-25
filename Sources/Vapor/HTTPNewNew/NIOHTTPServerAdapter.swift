import NIOHTTPServer
import NIOCore
import NIOConcurrencyHelpers
import Logging

/// Adapts `NIOHTTPServer` to Vapor's `Server` protocol using structured concurrency.
///
/// `run()` blocks for the server's lifetime. Graceful shutdown propagates from the
/// parent task (via `ServiceGroup` or task cancellation) through to
/// `NIOHTTPServer.serve()`'s built-in `withGracefulShutdownHandler`.
final class NIOHTTPServerAdapter: Server, Sendable {
    let application: Application
    private let addressContinuation: NIOLockedValueBox<CheckedContinuation<SocketAddress, any Error>?>

    init(application: Application) {
        self.application = application
        self.addressContinuation = .init(nil)
    }

    func run() async throws {
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

        // Run serve() in a child task so we can await listeningAddress
        // before serve() completes. The task group stays alive until serve() returns.
        try await withThrowingDiscardingTaskGroup { group in
            group.addTask {
                try await nioServer.serve(handler: handler)
            }

            // Wait for the server to bind, then publish the address
            let address = try await nioServer.listeningAddress
            let nioAddress = try NIOCore.SocketAddress.makeAddressResolvingHost(address.host, port: address.port)
            self.application.sharedNewAddress.withLockedValue { $0 = nioAddress }

            // Fulfill any waiting listeningAddress callers
            self.addressContinuation.withLockedValue { continuation in
                continuation?.resume(returning: nioAddress)
                continuation = nil
            }

            self.application.logger.notice("Server started on \(address.host):\(address.port)")
            // The task group blocks here until serve() finishes
            // (triggered by graceful shutdown or task cancellation)
        }
    }

    var listeningAddress: SocketAddress {
        get async throws {
            // If the address is already available, return it immediately
            if let address = self.application.sharedNewAddress.withLockedValue({ $0 }) {
                return address
            }
            // Otherwise wait for it via continuation
            return try await withCheckedThrowingContinuation { continuation in
                self.addressContinuation.withLockedValue { $0 = continuation }
            }
        }
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
