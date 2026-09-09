import NIOHTTPServer
import Synchronization
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

    /// The address was asked for after the server had stopped serving.
    case serverStopped
}

/// Adapts `NIOHTTPServer` to Vapor's `Server` protocol using structured concurrency.
///
/// `run()` blocks for the server's lifetime. Graceful shutdown propagates from the
/// parent task (via `ServiceGroup` or task cancellation) through to
/// `NIOHTTPServer.serve()`'s built-in `withGracefulShutdownHandler`.
final class NIOHTTPServerAdapter: Server, Sendable {
    // Handles queries to the server's address
    private struct AddressStateMachine {
        enum State {
            /// `run()` has not bound yet. The outcome is still unknown, so waiters park.
            case notStarted
            /// Bound and serving.
            case bound(SocketAddress)
            /// Startup failed, or the server died after binding. Retained so that a waiter arriving
            /// afterwards throws instead of parking on an address that will never be published.
            case failed(any Error)
            /// `run()` returned. Distinct from `notStarted` so a late waiter is told the server has
            /// gone rather than waiting for it to start.
            case stopped

            /// What a waiter should be handed in this state, or `nil` while the outcome is still
            /// unknown and the waiter has to park.
            var result: Result<SocketAddress, any Error>? {
                switch self {
                case .notStarted: nil
                case .bound(let address): .success(address)
                case .failed(let error): .failure(error)
                case .stopped: .failure(NIOHTTPServerAdapterError.serverStopped)
                }
            }
        }

        var state: State = .notStarted
        var continuations: [CheckedContinuation<SocketAddress, any Error>] = []

        /// Moves to `state`, handing back the parked waiters so they can be resumed outside the lock.
        mutating func transition(to state: State) -> [CheckedContinuation<SocketAddress, any Error>] {
            self.state = state
            defer { self.continuations = [] }
            return self.continuations
        }
    }

    let application: Application
    private let addressState = Mutex<AddressStateMachine>(.init())

    init(application: Application) {
        self.application = application
    }

    func run() async throws {
        do {
            try await self.runServer()
            self.transition(to: .stopped)
        } catch {
            self.transition(to: .failed(error))
            throw error
        }
    }

    /// Moves the address state on and resumes everyone parked on ``listeningAddress``.
    ///
    /// Continuations are resumed outside the lock: resuming wakes another task, which is not
    /// something to do while holding one.
    private func transition(to state: AddressStateMachine.State) {
        let waiting = self.addressState.withLock { $0.transition(to: state) }
        guard let result = state.result else { return }
        for continuation in waiting {
            continuation.resume(with: result)
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
            guard let address = addresses.first, let socketAddress = SocketAddress(address) else {
                throw NIOHTTPServerAdapterError.noListeningAddress
            }

            // Publish the address and resume anyone already waiting on it.
            self.transition(to: .bound(socketAddress))

            Logger.current.notice(
                "Server started",
                metadata: ["host": "\(address.host)", "port": "\(address.port)"])

            // Wait for serve() to complete (blocks until shutdown/cancellation)
            try await group.next()
        }
    }

    var listeningAddress: SocketAddress {
        get async throws {
            if let result = self.addressState.withLock({ $0.state.result }) {
                return try result.get()
            }
            return try await withCheckedThrowingContinuation { continuation in
                let result: Result<SocketAddress, any Error>? = self.addressState.withLock { state in
                    if let result = state.state.result {
                        return result
                    }
                    state.continuations.append(continuation)
                    return nil
                }
                if let result {
                    continuation.resume(with: result)
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
