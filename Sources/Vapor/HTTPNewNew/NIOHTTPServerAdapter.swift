import NIOHTTPServer
import NIOCore
import NIOConcurrencyHelpers
import Logging

/// Errors thrown by ``NIOHTTPServerAdapter``.
enum NIOHTTPServerAdapterError: Error {
    /// The underlying server reported that it was listening but exposed no addresses.
    case noListeningAddress
}

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
        let transportSecurity: NIOHTTPServerConfiguration.TransportSecurity
        if let tls = self.application.serverConfiguration.tlsConfiguration {
            let credentials: NIOHTTPServerConfiguration.TransportSecurity.TLSCredentials
            switch tls.source {
            case .inMemory(let chain, let key):
                credentials = .inMemory(certificateChain: chain, privateKey: key)
            case .pemFile(let certPath, let keyPath):
                credentials = .pemFile(certificateChainPath: certPath, privateKeyPath: keyPath)
            }
            transportSecurity = .tls(credentials: credentials)
        } else {
            transportSecurity = .plaintext
        }

        let (hostname, port) = self.resolveBindAddress()

        let configuration = try NIOHTTPServerConfiguration(
            bindTarget: .hostAndPort(host: hostname, port: port),
            supportedHTTPVersions: [.http1_1],
            transportSecurity: transportSecurity
        )

        let nioServer = NIOHTTPServer(
            logger: Logger.current,
            configuration: configuration
        )

        let responder: any Responder
        switch self.application.responder {
        case .default:
            responder = DefaultResponder(
                routes: self.application.routes,
                middleware: self.application.middleware.resolve(),
            )
        case .provided(let provided):
            responder = provided
        }

        let handler = VaporHTTPServerHandler(
            application: self.application,
            responder: responder
        )

        // Run serve() in a child task so we can await listeningAddress
        // before serve() completes.
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await nioServer.serve(handler: handler)
            }

            // Wait for the server to bind, then publish the address
            let addresses = try await nioServer.listeningAddresses
            guard let address = addresses.first else {
                throw NIOHTTPServerAdapterError.noListeningAddress
            }
            let nioAddress = try NIOCore.SocketAddress.makeAddressResolvingHost(address.host, port: address.port)

            // Atomically set the address and resume any waiting continuation
            self.application.sharedNewAddress.withLockedValue { $0 = nioAddress }
            self.addressContinuation.withLockedValue { continuation in
                continuation?.resume(returning: nioAddress)
                continuation = nil
            }

            Logger.current.notice("Server started on \(address.host):\(address.port)")

            // Wait for serve() to complete (blocks until shutdown/cancellation)
            try await group.next()
        }
    }

    var listeningAddress: SocketAddress {
        get async throws {
            // Check atomically: if address is already set, return it;
            // otherwise register a continuation to be fulfilled by run()
            let needsWait: Bool = self.application.sharedNewAddress.withLockedValue { address in
                address != nil ? false : true
            }
            if !needsWait {
                return self.application.sharedNewAddress.withLockedValue { $0! }
            }
            return try await withCheckedThrowingContinuation { continuation in
                // Double-check under lock: address may have been set between our check and here
                let alreadySet: SocketAddress? = self.addressContinuation.withLockedValue { cont in
                    if let address = self.application.sharedNewAddress.withLockedValue({ $0 }) {
                        return address
                    }
                    cont = continuation
                    return nil
                }
                if let address = alreadySet {
                    continuation.resume(returning: address)
                }
            }
        }
    }

    private func resolveBindAddress() -> (String, Int) {
        switch self.application.serverConfiguration.address {
        case .hostname(let hostname, let port):
            return (hostname, port)
        case .unixDomainSocket:
            Logger.current.warning("Unix domain sockets are not supported by NIOHTTPServer. Falling back to default address.")
            return ("127.0.0.1", 8080)
        }
    }
}
