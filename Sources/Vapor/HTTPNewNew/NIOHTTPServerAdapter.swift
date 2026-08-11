import NIOHTTPServer
import NIOCore
import NIOConcurrencyHelpers
import Logging

/// Errors thrown by ``NIOHTTPServerAdapter``.
enum NIOHTTPServerAdapterError: Error {
    /// The underlying server reported that it was listening but exposed no addresses.
    case noListeningAddress

    /// HTTP/2 was requested without TLS. HTTP/2 is only negotiated over TLS (via ALPN),
    /// so a ``ServerConfiguration/tlsConfiguration`` is required to serve it.
    case http2RequiresTLS
}

/// Adapts `NIOHTTPServer` to Vapor's `Server` protocol using structured concurrency.
///
/// `run()` blocks for the server's lifetime. Graceful shutdown propagates from the
/// parent task (via `ServiceGroup` or task cancellation) through to
/// `NIOHTTPServer.serve()`'s built-in `withGracefulShutdownHandler`.
final class NIOHTTPServerAdapter: Server, Sendable {
    /// Tracks anyone waiting on ``listeningAddress`` along with a startup failure, if one occurred.
    ///
    /// `startupError` is retained so that a waiter arriving *after* `run()` has already failed
    /// throws instead of waiting on an address that will never be published.
    private struct AddressWaiters {
        var continuation: CheckedContinuation<SocketAddress, any Error>?
        var startupError: (any Error)?
    }

    let application: Application
    private let addressWaiters: NIOLockedValueBox<AddressWaiters>

    init(application: Application) {
        self.application = application
        self.addressWaiters = .init(.init())
    }

    func run() async throws {
        do {
            try await self.runServer()
        } catch {
            // If we failed before publishing the listening address — bad TLS credentials, the port
            // already being in use, a bind failure — anyone awaiting `listeningAddress` would wait
            // forever, because only the success path below ever resumes them. Hand them the error.
            self.addressWaiters.withLockedValue { waiters in
                waiters.startupError = error
                waiters.continuation?.resume(throwing: error)
                waiters.continuation = nil
            }
            throw error
        }
    }

    private func runServer() async throws {
        let transportSecurity: NIOHTTPServerConfiguration.TransportSecurity
        if let tls = self.application.serverConfiguration.tlsConfiguration {
            let credentials: NIOHTTPServerConfiguration.TransportSecurity.TLSCredentials
            switch tls.source {
            case .inMemory(let chain, let key):
                credentials = .x509(.certificates(chain: chain, privateKey: key))
            case .pemFile(let certPath, let keyPath):
                credentials = .x509(.pemFile(certificateChainPath: certPath, privateKeyPath: keyPath))
            }
            transportSecurity = .tls(credentials: credentials)
        } else {
            transportSecurity = .plaintext
        }

        var supportedHTTPVersions = Set<NIOHTTPServerConfiguration.HTTPVersion>()
        for httpVersion in self.application.serverConfiguration.httpVersions {
            switch httpVersion.version {
            case .http1_1:
                supportedHTTPVersions.insert(.http1_1)
            case .http2(let config):
                supportedHTTPVersions.insert(.http2(
                    config: .init(
                        maxFrameSize: config.maxFrameSize,
                        targetWindowSize: config.targetWindowSize,
                        maxConcurrentStreams: config.maxConcurrentStreams,
                        gracefulShutdown: .init(
                            maximumGracefulShutdownDuration: config.gracefulShutdown.maximumGracefulShutdownDuration
                        )
                    )
                ))
            }
        }

        // HTTP/2 is negotiated via ALPN, which requires TLS. Over plaintext, only HTTP/1.1 is allowed.
        if !self.application.serverConfiguration.isTLSEnabled {
            guard self.application.serverConfiguration.httpVersions == [.http1_1] else {
                throw NIOHTTPServerAdapterError.http2RequiresTLS
            }
        }

        let (hostname, port) = self.resolveBindAddress()

        let configuration = try NIOHTTPServerConfiguration(
            bindTarget: .hostAndPort(host: hostname, port: port),
            supportedHTTPVersions: supportedHTTPVersions,
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
            self.addressWaiters.withLockedValue { waiters in
                waiters.continuation?.resume(returning: nioAddress)
                waiters.continuation = nil
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
            enum Resolution {
                case address(SocketAddress)
                case failure(any Error)
                case waiting
            }
            return try await withCheckedThrowingContinuation { continuation in
                // Double-check under lock: the address may have been published, or startup may have
                // failed outright, between our check above and here.
                let resolution: Resolution = self.addressWaiters.withLockedValue { waiters in
                    if let address = self.application.sharedNewAddress.withLockedValue({ $0 }) {
                        return .address(address)
                    }
                    if let error = waiters.startupError {
                        return .failure(error)
                    }
                    waiters.continuation = continuation
                    return .waiting
                }
                switch resolution {
                case .address(let address):
                    continuation.resume(returning: address)
                case .failure(let error):
                    continuation.resume(throwing: error)
                case .waiting:
                    break
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
