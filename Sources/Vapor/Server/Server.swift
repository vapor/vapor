import NIOCore

// TODO: Remove these deprecated methods along with ServerStartError in the major release.
public protocol Server {
    var onShutdown: EventLoopFuture<Void> { get }
    
    /// Start the server with the specified address.
    /// - Parameters:
    ///   - address: The address to start the server with.
    func start(address: BindAddress?) throws
    
    /// Start the server with the specified hostname and port, if provided. If left blank, the server will be started with its default configuration.
    /// - Deprecated: Please use `start(address: .hostname(hostname, port: port))` instead.
    /// - Parameters:
    ///   - hostname: The hostname to start the server with, or nil if the default one should be used.
    ///   - port: The port to start the server with, or nil if the default one should be used.
    @available(*, deprecated, renamed: "start(address:)", message: "Please use `start(address: .hostname(hostname, port: port))` instead")
    func start(hostname: String?, port: Int?) throws
    
    func shutdown()
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
    
    /// A default implementation that throws `ServerStartError.unsupportedAddress` for `.unixDomainSocket(path:)` if `start(address:)` is not implemented by the conforming type, or calls the deprecated `.start(hostname:port:)` method for other cases.
    @available(*, deprecated, message: "The Server receiving this message does not support all address types, and must be updated.")
    public func start(address: BindAddress?) throws {
        switch address {
        case .none:
            try self.start(hostname: nil, port: nil)
        case .hostname(let hostname, let port):
            try self.start(hostname: hostname, port: port)
        case .unixDomainSocket:
            throw ServerStartError.unsupportedAddress(message: "Starting with unix domain socket path not supported, \(Self.self) must implement start(address:).")
        }
    }
    
    /// Start the server with the specified hostname and port, if provided. If left blank, the server will be started with its default configuration.
    /// - Deprecated: Please use `start(address: .hostname(hostname, port: port))` instead.
    /// - Parameters:
    ///   - hostname: The hostname to start the server with, or nil if the default one should be used.
    ///   - port: The port to start the server with, or nil if the default one should be used.
    @available(*, deprecated, renamed: "start(address:)", message: "Please use `start(address: .hostname(hostname, port: port))` instead")
    public func start(hostname: String?, port: Int?) throws {
        try self.start(address: .hostname(hostname, port: port))
    }
}

/// Errors that may be thrown when starting a server
internal enum ServerStartError: Error, Sendable {
    /// Incompatible flags were used together (for instance, specifying a socket path along with a port)
    case unsupportedAddress(message: String)
}

