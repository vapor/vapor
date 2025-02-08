import NIOCore

public protocol Server: Sendable {    
    /// Start the server with the specified address.
    /// - Parameters:
    ///   - address: The address to start the server with.
    func start(address: BindAddress?) async throws
    
    /// Shut the server down.
    func shutdown() async throws
}

public enum BindAddress: Equatable, Sendable {
    case hostname(_ hostname: String?, port: Int?)
    case unixDomainSocket(path: String)
}

extension Server {
    /// Start the server with its default configuration, listening over a regular TCP socket.
    /// - Throws: An error if the server could not be started.
    public func start() async throws {
        try await self.start(address: nil)
    }
}
