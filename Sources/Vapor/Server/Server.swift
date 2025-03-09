import HTTPServerNew

public protocol Server: Sendable {    
    /// Start the server with its default configuration, listening over a regular TCP socket.
    /// - Throws: An error if the server could not be started.
    func start() async throws
    
    /// Shut the server down.
    func shutdown() async throws
}

public enum BindAddress: Equatable, Sendable {
    case hostname(_ hostname: String?, port: Int?)
    case unixDomainSocket(path: String)
}
