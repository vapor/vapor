import HTTP
import TCP

/// A TCP based server with HTTP parsing and serialization pipeline.
public final class EngineServer: HTTPServer {
    /// Chosen configuration for this server.
    public let config: EngineServerConfig

    /// Create a new EngineServer using config struct.
    public init(config: EngineServerConfig) {
        self.config = config
    }

    /// Start the server. Server protocol requirement.
    public func start(with responder: Responder) throws {
        // create a tcp server
        let tcp = try TCP.Server(workerCount: config.workerCount)
        let server = HTTP.Server(tcp: tcp)

        // setup the server pipeline
        server.drain { client in
            let parser = HTTP.RequestParser(queue: client.tcp.queue)
            let responderStream = responder.makeStream()
            let serializer = HTTP.ResponseSerializer()

            client.stream(to: parser)
                .stream(to: responderStream)
                .stream(to: serializer)
                .drain(into: client)

            client.tcp.start()
        }

        server.errorStream = { error in
            debugPrint(error)
        }

        // bind, listen, and start accepting
        try server.tcp.start(
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

    /// Listen backlog.
    public let backlog: Int32

    /// Number of client accepting workers.
    /// Should be equal to the number of logical cores.
    public let workerCount: Int

    /// Creates a new engine server config
    public init(
        hostname: String = "localhost",
        port: UInt16 = 8080,
        backlog: Int32 = 4096,
        workerCount: Int = 8
    ) {
        self.hostname = hostname
        self.port = port
        self.backlog = backlog
        self.workerCount = workerCount
    }
}
