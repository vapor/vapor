import Async
import Bits
import Console
import Debugging
import Dispatch
import Foundation
import HTTP
import ServerSecurity
import Service
import TCP
import TLS

#if os(Linux)
    import OpenSSL
#else
    import AppleTLS
#endif

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
        let workers = try (0..<config.workerCount).map { i -> EngineWorker in
            // create new event loop
            let eventLoop = try DefaultEventLoop(label: "codes.vapor.engine.server.worker.\(i)")
            return EngineWorker(
                container: container.subContainer(on: eventLoop),
                responder: responder
            )
        }
        
        let accept = try DefaultEventLoop(label: "codes.vapor.engine.server.accept")

        try startPlain(workers: workers, accept: accept)

        if let ssl = config.ssl {
            try startSSL(workers: workers, accept: accept, ssl: ssl)
        }

        // non-blocking main thread run
        accept.runLoop()
    }
    
    private func startPlain(workers: [EngineWorker], accept: EventLoop) throws {
        var tcpServer = try TCPServer(socket: TCPSocket(isNonBlocking: true))
        tcpServer.willAccept = PeerValidator(maxConnectionsPerIP: config.maxConnectionsPerIP).willAccept
        
        let server = HTTPServer(
            acceptStream: tcpServer.stream(on: accept),
            workers: workers
        )

        let console = try container.make(Console.self, for: EngineServer.self)
        let logger = try container.make(Logger.self, for: EngineServer.self)

        server.onError = { error in
            logger.reportError(error, as: "Server Error")
        }

        console.print("Server starting on ", newLine: false)
        console.output("http://" + config.hostname, style: .init(color: .cyan), newLine: false)
        console.output(":" + config.port.description, style: .init(color: .cyan))
    }

    private func startSSL<EngineWorker: Worker & HTTPResponder>(workers: [EngineWorker], accept: EventLoop, ssl: EngineServerSSLConfig) throws {
        #if os(Linux)
            throw VaporError(identifier: "ssl-server-linux", reason: "SSL servers are yet unsupported on Linux")
        #else
            // create a tcp server
            var tcpServer = try TCPServer(socket: TCPSocket(isNonBlocking: true))
            tcpServer.willAccept = PeerValidator(maxConnectionsPerIP: config.maxConnectionsPerIP).willAccept
            
            let stream = tcpServer.stream(on: accept).map(to: AppleTLSSocket.self) { client in
                let client = try AppleTLSClient(tcp: client, using: ssl.settings).socket
                try client.prepareSocket()
                return client
            }
            
            let server = HTTPServer(acceptStream: stream, workers: workers)
            
            let console = try container.make(Console.self, for: EngineServer.self)
            let logger = try container.make(Logger.self, for: EngineServer.self)
            
            server.onError = { error in
                logger.reportError(error, as: "Server Error")
            }
        #endif
        
        console.print("Server starting on ", newLine: false)
        console.output("http://" + config.hostname, style: .init(color: .cyan), newLine: false)
        console.output(":" + config.port.description, style: .init(color: .cyan))
    }
}

fileprivate struct EngineWorker: HTTPResponder, Worker {
    var eventLoop: EventLoop {
        return container.eventLoop
    }
    let responder: Responder
    let container: Container

    init(container: Container, responder: Responder) {
        self.container = container
        self.responder = responder
    }

    func respond(to httpRequest: HTTPRequest, on worker: Worker) throws -> Future<HTTPResponse> {
        return Future {
            let req = Request(http: httpRequest, using: self.container)
            return try self.responder.respond(to: req)
                .map(to: HTTPResponse.self) { $0.http }
        }
    }
}

extension Logger {
    func reportError(_ error: Error, as label: String) {
        var string = "\(label): "
        if let debuggable = error as? Debuggable {
            string += debuggable.fullIdentifier
            string += ": "
            string += debuggable.reason
        } else {
            string += "\(error)"
        }
        if let traceable = error as? Traceable {
            self.error(string,
                file: traceable.file,
                function: traceable.function,
                line: traceable.line,
                column: traceable.column
            )
        } else {
            self.error(string)
        }
    }
}

/// The EngineServer's SSL configuration
public struct EngineServerSSLConfig {
    /// Host name the SSL server will bind to.
    public var hostname: String
    
    /// The port to bind the HTTPS server to
    public var port: UInt16
    
    /// Listen backlog.
    public var backlog: Int32
    
    /// Number of client accepting workers.
    /// Should be equal to the number of logical cores.
    public var workerCount: Int

    /// The SSL settings (such as the certificate)
    public var settings: TLSServerSettings

    public init(settings: TLSServerSettings) {
        self.hostname = "localhost"
        self.settings = settings
        self.port = 443
        self.workerCount = ProcessInfo.processInfo.activeProcessorCount
        self.backlog = 4096
    }
}

/// Engine server config struct.
public struct EngineServerConfig {
    /// Host name the server will bind to.
    public var hostname: String

    /// Port the server will bind to.
    public var port: UInt16

    /// Listen backlog.
    public var backlog: Int32

    /// Number of client accepting workers.
    /// Should be equal to the number of logical cores.
    public var workerCount: Int
    
    /// Limits the amount of connections per IP address to prevent certain Denial of Service attacks
    public var maxConnectionsPerIP: Int
    
    /// The SSL configuration. If it exists, SSL will be used
    public var ssl: EngineServerSSLConfig?

    /// Creates a new engine server config
    public init(
        hostname: String = "localhost",
        port: UInt16 = 8080,
        maxConnectionsPerIP: Int = 128
    ) {
        self.hostname = hostname
        self.port = port
        self.workerCount = ProcessInfo.processInfo.activeProcessorCount
        self.backlog = 4096
        self.maxConnectionsPerIP = maxConnectionsPerIP
        // self.ssl = nil
    }
}
