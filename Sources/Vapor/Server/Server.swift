import HTTPServerNew

public protocol Server: Sendable {    
    /// Start the server with its default configuration, listening over a regular TCP socket.
    /// - Throws: An error if the server could not be started.
    func start() async throws
    
    /// Shut the server down.
    func shutdown() async throws
}

public enum BindAddress: Equatable, Sendable {
    case hostname(_ hostname: String = "127.0.0.1", port: Int = 8080)
    case unixDomainSocket(path: String)
}
