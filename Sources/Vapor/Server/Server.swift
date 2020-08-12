// TODO: Remove these deprecated methods for the next major release.
public protocol Server {
    var onShutdown: EventLoopFuture<Void> { get }
    
    /// Start the server with the specified address.
    /// - Parameters:
    ///   - address: The address to start the server with.
    func start(address: BindAddress) throws
    
    func start(hostname: String?, port: Int?) throws
    
    func shutdown()
}

public enum BindAddress {
    case hostname(_ hostname: String?, port: Int?)
    case unixDomainSocket(path: String)
}

extension Server {
    /// Start the server with its default configuration, listening over a regular TCP socket.
    /// - Throws: An error if the server could not be started.
    public func start() throws {
        try self.start(address: .hostname(nil, port: nil))
    }
    
    /// A default implementation that throws an unimplemented assertion.
    public func start(address: BindAddress) throws {
        preconditionFailure("\(self) does not support being started on: \(address)")
    }
    
    /// Start the server with the specified hostname and port, if provided. If left blank, the server will be started with its default configuration.
    /// - Parameters:
    ///   - hostname: The hostname to start the server with, or nil if the default one should be used.
    ///   - port: The port to start the server with, or nil if the default one should be used.
    public func start(hostname: String?, port: Int?) throws {
        try self.start(address: .hostname(hostname, port: port))
    }
}
