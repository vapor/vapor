public protocol Server {
    var onShutdown: EventLoopFuture<Void> { get }
    
    /// Start the server with the specified hostname and port, if provided. If left blank, the server will be started with its default configuration.
    /// - Parameters:
    ///   - hostname: The hostname to start the server with, or nil if the default one should be used.
    ///   - port: The port to start the server with, or nil if the default one should be used.
    func start(hostname: String?, port: Int?) throws
    
    /// Start the server with the specified socket file.
    /// - Parameter socketPath: The path to the unix domain socket file.
    func start(socketPath: String) throws
    
    func shutdown()
}

extension Server {
    /// Start the server with its default configuration.
    /// - Throws: An error if the server could not be started.
    public func start() throws {
        try self.start(hostname: nil, port: nil)
    }
    
    /// A default implementation that throws an unimplemented assertion.
    public func start(socketPath: String) throws {
        preconditionFailure("\(self) does not support being started with a socketPath")
    }
}
