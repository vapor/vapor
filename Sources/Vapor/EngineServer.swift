import Async
import Console
import Dispatch
import HTTP
import ServerSecurity
import TCP

/// A TCP based server with HTTP parsing and serialization pipeline.
public final class EngineServer: HTTPServer {
    /// Chosen configuration for this server.
    public let config: EngineServerConfig

    /// Console for outputting server messages.
    public let console: Console

    /// Create a new EngineServer using config struct.
    public init(
        config: EngineServerConfig,
        console: Console
    ) {
        self.config = config
        self.console = console
    }

    /// Start the server. Server protocol requirement.
    public func start(with responder: Responder) throws {
        // create a tcp server
        let tcp = try TCP.Server(workerCount: config.workerCount)
        
        tcp.willAccept = PeerValidator(maxConnectionsPerIP: config.maxConnectionsPerIP).willAccept
        
        let server = HTTP.Server(clientStream: tcp)
        
        // setup the server pipeline
        server.drain { client in
            let parser = HTTP.RequestParser(worker: client.tcp.worker, maxBodySize: 10_000_000)
            let responderStream = responder.makeStream()
            let serializer = HTTP.ResponseSerializer()
            
            client.stream(to: parser)
                .stream(to: responderStream)
                .stream(to: serializer)
                .drain { data in
                    client.inputStream(data)
                    serializer.upgradeHandler?(client.tcp)
                }

            client.tcp.start()
        }.catch { error in
            debugPrint(error)
        }

        console.print("Server starting on ", newLine: false)
        console.output("http://" + config.hostname, style: .custom(.cyan), newLine: false)
        console.output(":" + config.port.description, style: .custom(.cyan))

        // bind, listen, and start accepting
        try tcp.start(
            hostname: config.hostname,
            port: config.port,
            backlog: config.backlog
        )

        let group = DispatchGroup()
        group.enter()
        group.wait()
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
    
    /// Limits the amount of connections per IP address to prevent certain Denial of Service attacks
    public let maxConnectionsPerIP: Int

    /// Creates a new engine server config
    public init(
        hostname: String = "localhost",
        port: UInt16 = 8080,
        backlog: Int32 = 4096,
        workerCount: Int = 8,
        maxConnectionsPerIP: Int = 128
    ) {
        self.hostname = hostname
        self.port = port
        self.backlog = backlog
        self.workerCount = workerCount
        self.maxConnectionsPerIP = maxConnectionsPerIP
    }
}
