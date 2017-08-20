import HTTP
import TCP

/// A TCP based server with HTTP parsing and serialization pipeline.
public final class EngineServer: Server {
    /// Chosen configuration for this server.
    public let config: EngineServerConfig

    /// Create a new EngineServer using config struct.
    public init(config: EngineServerConfig) {
        self.config = config
    }

    /// Start the server. Server protocol requirement.
    public func start(with responder: Responder) throws {
        // create a tcp server
        let server = try TCP.Server(workerCount: config.workerCount)

        // setup the server pipeline
        server.consume { client in
            let parser = HTTP.RequestParser()
            let serializer = HTTP.ResponseSerializer()

            client.stream(to: parser)
                .stream(to: responder.makeStream())
                .stream(to: serializer)
                .consume(into: client)

            client.start()
        }

        // bind, listen, and start accepting
        try server.start(
            hostname: config.hostname,
            port: config.port,
            backlog: config.backlog
        )
    }
}

/// Engine server config struct.
public struct EngineServerConfig {
    /// Host name the server will bind to.
    public let hostname: String

    /// Port the server will bind to.
    public let port: UInt16

    /// Number of dispatch queues for processing requests.
    /// This should be 2x the number of physical CPUs in target machine.
    public let workerCount: Int

    /// Listen backlog.
    public let backlog: Int32

    /// Creates a new engine server config
    public init(
        hostname: String = "localhost",
        port: UInt16 = 8080,
        workerCount: Int = 8,
        backlog: Int32 = 4096
    ) {
        self.hostname = hostname
        self.port = port
        self.workerCount = workerCount
        self.backlog = backlog
    }
}
