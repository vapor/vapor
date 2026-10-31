public import ServiceLifecycle

/// A server that can handle HTTP requests.
public protocol Server: Service, Sendable {
    /// The address the server is listening on. Suspends until the server has bound or throws an error
    /// if the server failed to start, or if stopped
    var listeningAddress: SocketAddress { get async throws }
}

public enum BindAddress: Equatable, Sendable {
    case hostname(_ hostname: String = "127.0.0.1", port: Int = 8080)
    case unixDomainSocket(path: String)
}
