/// Engine server config struct.
///
///     let serverConfig = EngineServerConfig.default(port: 8123)
///     services.register(serverConfig)
///
public struct EngineServerConfig: ServiceType {
    /// See `ServiceType`.
    public static func makeService(for worker: Container) throws -> EngineServerConfig {
        return .default()
    }

    /// Detects `EngineServerConfig` from the environment.
    ///
    /// - parameters:
    ///     - hostname: Socket hostname to bind to. Usually `localhost` or `::1`.
    ///     - port: Socket port to bind to. Usually `8080` for development and `80` for production.
    ///     - backlog: OS socket backlog size.
    ///     - workerCount: Number of `Worker`s to use for responding to incoming requests.
    ///                    This should be (and is by default) equal to the number of logical cores.
    ///     - maxBodySize: Requests with bodies larger than this maximum will be rejected.
    ///                    Streaming bodies, like chunked bodies, ignore this maximum.
    ///     - reuseAddress: When `true`, can prevent errors re-binding to a socket after successive server restarts.
    ///     - tcpNoDelay: When `true`, OS will attempt to minimize TCP packet delay.
    public static func `default`(
        hostname: String = "localhost",
        port: Int = 8080,
        backlog: Int = 256,
        workerCount: Int = ProcessInfo.processInfo.activeProcessorCount,
        maxBodySize: Int = 1_000_0000,
        reuseAddress: Bool = true,
        tcpNoDelay: Bool = true
    ) -> EngineServerConfig {
        return EngineServerConfig(
            hostname: hostname,
            port: port,
            backlog: backlog,
            workerCount: workerCount,
            maxBodySize: maxBodySize,
            reuseAddress: reuseAddress,
            tcpNoDelay: tcpNoDelay
        )
    }

    /// Host name the server will bind to.
    public var hostname: String

    /// Port the server will bind to.
    public var port: Int

    /// Listen backlog.
    public var backlog: Int

    /// Number of client accepting workers.
    /// Should be equal to the number of logical cores.
    public var workerCount: Int

    /// Requests containing bodies larger than this maximum will be rejected, closign the connection.
    public var maxBodySize: Int

    /// When `true`, can prevent errors re-binding to a socket after successive server restarts.
    public var reuseAddress: Bool

    /// When `true`, OS will attempt to minimize TCP packet delay.
    public var tcpNoDelay: Bool

    /// Creates a new `EngineServerConfig`.
    public init(
        hostname: String,
        port: Int,
        backlog: Int,
        workerCount: Int,
        maxBodySize: Int,
        reuseAddress: Bool,
        tcpNoDelay: Bool
    ) {
        self.hostname = hostname
        self.port = port
        self.backlog = backlog
        self.workerCount = workerCount
        self.maxBodySize = maxBodySize
        self.reuseAddress = reuseAddress
        self.tcpNoDelay = tcpNoDelay
    }
}
