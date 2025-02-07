import NIOCore

#warning("TODO")
// TODO: Remove these deprecated methods along with ServerStartError in the major release.
public protocol Server: Sendable {
    var onShutdown: EventLoopFuture<Void> { get }
    
    /// Start the server with the specified address.
    /// - Parameters:
    ///   - address: The address to start the server with.
    @available(*, noasync, message: "Use the async start() method instead.")
    func start(address: BindAddress?) throws
    
    /// Start the server with the specified address.
    /// - Parameters:
    ///   - address: The address to start the server with.
    func start(address: BindAddress?) async throws
    
    /// Shut the server down.
    @available(*, noasync, message: "Use the async start() method instead.")
    func shutdown()
    
    /// Shut the server down.
    func shutdown() async
}

public enum BindAddress: Equatable, Sendable {
    case hostname(_ hostname: String?, port: Int?)
    case unixDomainSocket(path: String)
}

extension Server {
    /// Start the server with its default configuration, listening over a regular TCP socket.
    /// - Throws: An error if the server could not be started.
    public func start() throws {
        try self.start(address: nil)
    }
    
    // Trick the compiler
    private func syncStart(address: BindAddress?) throws {
        try self.start(address: address)
    }
    
    private func syncShutdown() {
        self.shutdown()
    }
}

/// Errors that may be thrown when starting a server
internal enum ServerStartError: Error {
    /// Incompatible flags were used together (for instance, specifying a socket path along with a port)
    case unsupportedAddress(message: String)
}

