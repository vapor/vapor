import NIOHTTPServer
import NIOCore
import NIOConcurrencyHelpers
import Logging

/// Errors thrown by ``NIOHTTPServerAdapter``.
enum NIOHTTPServerAdapterError: Error {
    /// The underlying server reported that it was listening but exposed no addresses.
    case noListeningAddress

    /// HTTP/2 was requested without TLS. HTTP/2 is negotiated over TLS via ALPN, so a
    /// ``ServerConfiguration/tlsConfiguration`` is required to serve it. Cleartext HTTP/2 (h2c) is not
    /// supported by the underlying server yet; if that changes this check will be gated behind an opt-in.
    case http2RequiresTLS

    /// No HTTP versions were configured. ``ServerConfiguration/httpVersions`` must contain at least one version.
    case noHTTPVersionsSpecified

    /// The in-memory TLS credentials carried an empty certificate chain. A server has nothing to present
    /// during the handshake without at least a leaf certificate.
    case emptyCertificateChain
}

/// Adapts `NIOHTTPServer` to Vapor's `Server` protocol using structured concurrency.
///
/// `run()` blocks for the server's lifetime. Graceful shutdown propagates from the
/// parent task (via `ServiceGroup` or task cancellation) through to
/// `NIOHTTPServer.serve()`'s built-in `withGracefulShutdownHandler`.
final class NIOHTTPServerAdapter: Server, Sendable {
    /// Tracks everyone waiting on ``listeningAddress`` along with a startup failure, if one occurred.
    ///
    /// `startupError` is retained so that a waiter arriving *after* `run()` has already failed
    /// throws instead of waiting on an address that will never be published.
    ///
    /// Waiters are held in an array rather than a single slot: nothing stops two tasks awaiting the
    /// address at once, and with one slot the second would overwrite the first, leaving it parked
    /// forever on a continuation nobody resumes.
    private struct AddressWaiters {
        var continuations: [CheckedContinuation<SocketAddress, any Error>] = []
        var startupError: (any Error)?

        /// Removes the parked waiters, for resuming outside the lock.
        mutating func takeContinuations() -> [CheckedContinuation<SocketAddress, any Error>] {
            defer { self.continuations = [] }
            return self.continuations
        }
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
            let waiting = self.addressWaiters.withLockedValue { waiters in
                waiters.startupError = error
                return waiters.takeContinuations()
            }
            for continuation in waiting {
                continuation.resume(throwing: error)
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
                guard !chain.isEmpty else {
                    throw NIOHTTPServerAdapterError.emptyCertificateChain
                }
                credentials = .x509(.certificates(chain: chain, privateKey: key))
            case .pemFile(let certPath, let keyPath):
                credentials = .x509(.pemFile(certificateChainPath: certPath, privateKeyPath: keyPath))
            case .reloading(let reloader):
                credentials = .x509(.reloading(reloader))
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

        guard !self.application.serverConfiguration.httpVersions.isEmpty else {
            throw NIOHTTPServerAdapterError.noHTTPVersionsSpecified
        }

        // HTTP/2 is negotiated via ALPN, which requires TLS. Over plaintext, only HTTP/1.1 is allowed.
        guard self.application.serverConfiguration.isTLSEnabled
            || self.application.serverConfiguration.httpVersions == [.http1_1]
        else {
            throw NIOHTTPServerAdapterError.http2RequiresTLS
        }

        let (hostname, port) = self.resolveBindAddress()

        let configuration = try NIOHTTPServerConfiguration(
            bindTarget: .hostAndPort(host: hostname, port: port),
            supportedHTTPVersions: supportedHTTPVersions,
            transportSecurity: transportSecurity
        )

        let nioServer = NIOHTTPServer(
            configuration: configuration
        )

        let handler = VaporHTTPServerHandler(
            application: self.application,
            responder: self.application.makeResponder()
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
            self.application.sharedAddress.withLockedValue { $0 = nioAddress }
            let waiting = self.addressWaiters.withLockedValue { $0.takeContinuations() }
            for continuation in waiting {
                continuation.resume(returning: nioAddress)
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
            let needsWait: Bool = self.application.sharedAddress.withLockedValue { address in
                address != nil ? false : true
            }
            if !needsWait {
                return self.application.sharedAddress.withLockedValue { $0! }
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
                    if let address = self.application.sharedAddress.withLockedValue({ $0 }) {
                        return .address(address)
                    }
                    if let error = waiters.startupError {
                        return .failure(error)
                    }
                    waiters.continuations.append(continuation)
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
