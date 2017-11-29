import Async
import Console
import Debugging
import Dispatch
import HTTP
import ServerSecurity
import TCP

/// A TCP based server with HTTP parsing and serialization pipeline.
public final class EngineServer: Server {
    /// Chosen configuration for this server.
    public let config: EngineServerConfig

    /// Container for setting on event loops.
    public let container: Container

    /// Create a new EngineServer using config struct.
    public init(
        config: EngineServerConfig,
        container: Container
    ) {
        self.config = config
        self.container = container
    }

    /// Start the server. Server protocol requirement.
    public func start(with responder: Responder) throws {
        // create a tcp server
        let tcp = try TCPServer(eventLoopCount: config.workerCount)

        // set container on each event loop
        tcp.eventLoops.forEach { $0.container = self.container }

        tcp.willAccept = PeerValidator(maxConnectionsPerIP: config.maxConnectionsPerIP).willAccept
        let server = HTTPServer(socket: tcp)

        let console = try container.make(Console.self, for: EngineServer.self)
        
        // setup the server pipeline
        server.drain { client in
            let parser = HTTP.RequestParser(on: client.tcp.worker, maxSize: 10_000_000)
            let responderStream = responder.makeStream()
            let serializer = HTTP.ResponseSerializer()
            
            client.stream(to: parser)
                .stream(to: responderStream)
                .stream(to: serializer)
                .drain { data in
                    client.onInput(data)
                    serializer.upgradeHandler?(client.tcp)
                }.catch { err in
                    /// FIXME: use log protocol?
                    console.reportError(err, as: "Uncaught error")
                    client.close()
                }.finally {
                    // client closed
                }

            client.tcp.start()
        }.catch { err in
            console.reportError(err, as: "Server error")
            debugPrint(err)
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

extension Console {
    fileprivate func reportError(_ error: Error, as label: String) {
        self.error("\(label): ", newLine: false)
        if let debuggable = error as? Debuggable {
            self.print(debuggable.fullIdentifier)
            self.print(debuggable.debuggableHelp(format: .short))
        } else {
            self.print("\(error)")
        }
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
