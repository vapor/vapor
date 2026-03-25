import ServiceLifecycle
import NIOCore

/// A server that can handle HTTP requests.
///
/// Conforms to `Service` from swift-service-lifecycle. Implementations
/// provide a `run()` method that blocks for the server's lifetime and
/// responds to graceful shutdown via task cancellation.
public protocol Server: Service, Sendable {
    /// The address the server is listening on.
    /// Awaits until the server has successfully bound.
    var listeningAddress: SocketAddress { get async throws }
}

public enum BindAddress: Equatable, Sendable {
    case hostname(_ hostname: String = "127.0.0.1", port: Int = 8080)
    case unixDomainSocket(path: String)
}
