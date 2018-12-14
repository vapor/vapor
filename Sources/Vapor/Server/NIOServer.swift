///// Vapor's default `Server` implementation. Built on SwiftNIO-based `HTTPServer`.
//public final class NIOServer: Server {
//    /// See `ServiceType`.
//    public static var serviceSupports: [Any.Type] { return [Server.self] }
//
//    /// See `ServiceType`.
//    public static func makeService(for container: Container) throws -> NIOServer {
//        return try NIOServer(config: container.make(), container: container)
//    }
//
//    /// Chosen configuration for this server.
//    public let config: NIOServerConfig
//
//    /// Container for setting on event loops.
//    public let container: Container
//
//    /// Hold the current worker. Used for deinit.
//    private var currentWorker: Worker?
//
//    /// Create a new `NIOServer`.
//    ///
//    /// - parameters:
//    ///     - config: Server preferences such as hostname, port, max body size, etc.
//    ///     - container: Root service-container to use for all event loops the server will create.
//    public init(config: NIOServerConfig, container: Container) {
//        self.config = config
//        self.container = container
//    }
//}
