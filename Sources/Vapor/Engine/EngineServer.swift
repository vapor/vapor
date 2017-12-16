import Async
import Bits
import Console
import JunkDrawer
import Debugging
import Dispatch
import Foundation
import HTTP
import ServerSecurity
import Service
import TCP
import TLS

/// A TCP based server with HTTP parsing and serialization pipeline.
public final class EngineServer: Server {
    /// Chosen configuration for this server.
    public let config: EngineServerConfig

    /// Container for setting on event loops.
    public let container: Container
    
    private let acceptQueue = DispatchQueue(label: "codes.vapor.net.tcp.server", qos: .background)
    
    var strongRef: Any?

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
        var eventLoops: [BasicSubContainer] = []
        for i in 0..<config.workerCount {
            // create new event loop
            let queue = DispatchQueue(label: "codes.vapor.engine.server.worker.\(i)")

            // copy services into new container
            let eventLoop = self.container.makeSubContainer(on: queue)
            eventLoops.append(eventLoop)
        }

        let tcpSocket = try TCPSocket(isNonBlocking: true)
        var tcpServer = try TCPServer(socket: tcpSocket)
        tcpServer.willAccept = PeerValidator(maxConnectionsPerIP: config.maxConnectionsPerIP).willAccept
        let tcpStream = tcpServer.stream(
            on: container.makeSubContainer(
                on: DispatchQueue(label: "codes.vapor.engine.server.main")
            ),
            assigning: eventLoops
        )
        let server = HTTPServer(acceptStream: tcpStream) { byteStream in
            return ResponderStream(
                responder: responder,
                using: byteStream.eventLoop
            )
        }

        let console = try container.make(Console.self, for: EngineServer.self)
        let logger = try container.make(Logger.self, for: EngineServer.self)

        server.onError = { error in
            logger.reportError(error, as: "Server Error")
        }

        console.print("Server starting on ", newLine: false)
        console.output("http://" + config.hostname, style: .custom(.cyan), newLine: false)
        console.output(":" + config.port.description, style: .custom(.cyan))

        // bind, listen, and start accepting
        try tcpServer.start(
            hostname: config.hostname,
            port: config.port,
            backlog: config.backlog
        )
//
//        try startPlain(with: responder)

//        if let sslConfig = config.ssl {
//            try startSSL(with: responder, sslConfig: sslConfig)
//        }

        // non-blocking main thread run
        RunLoop.main.run()
    }
    
//    private func startPlain(with responder: Responder) throws {
//        // create a tcp server
//        let tcp = try TCPServer(eventLoops: eventLoops.map { $0.queue }, acceptQueue: acceptQueue)
//
//        tcp.willAccept = PeerValidator(maxConnectionsPerIP: config.maxConnectionsPerIP).willAccept
//
//        let mapStream = MapStream<TCPClient, HTTPPeer>(map: HTTPPeer.init)
//        let server = HTTPServer<HTTPPeer>(socket: tcp.stream(to: mapStream))
//
//        var eventLoopsIterator = LoopIterator<[Container]>(collection: eventLoops)
//
//        // setup the server pipeline
//        server.start {
//            return ResponderStream(
//                responder: responder,
//                using: eventLoopsIterator.next()!
//            )
//        }.catch { err in
//            logger.reportError(err, as: "Server error")
//            debugPrint(err)
//        }.finally {
//            // on close
//        }
//
//
//    }

//    private func startSSL(with responder: Responder, sslConfig: EngineServerSSLConfig) throws {
//        // create a tcp server
//        let tcp = try TCPServer(eventLoops: eventLoops.map { $0.queue }, acceptQueue: acceptQueue)
//        
//        tcp.willAccept = PeerValidator(maxConnectionsPerIP: config.maxConnectionsPerIP).willAccept
//        
//        let upgrader = try container.make(SSLPeerUpgrader.self, for: EngineServer.self)
//        
//        let sslStream = FutureMapStream<TCPClient, BasicSSLPeer> { client in
//            return try client.eventLoop.queue.sync {
//                client.disableReadSource()
//                return try upgrader.upgrade(socket: client.socket, settings: sslConfig.sslSettings, eventLoop: client.eventLoop)
//            }
//        }
//        
//        let peerStream = tcp.stream(to: sslStream).map(HTTPPeer.init)
//        
//        let server = HTTPServer<HTTPPeer>(socket: peerStream)
//        
//        let console = try container.make(Console.self, for: EngineServer.self)
//        let logger = try container.make(Logger.self, for: EngineServer.self)
//        
//        var eventLoopsIterator = LoopIterator<[Container]>(collection: eventLoops)
//        
//        // setup the server pipeline
//        server.start {
//            return ResponderStream(
//                responder: responder,
//                using: eventLoopsIterator.next()!
//            )
//        }.catch { err in
//            logger.reportError(err, as: "Server error")
//            debugPrint(err)
//        }.finally {
//            // on close
//        }
//        
//        console.print("Server starting on ", newLine: false)
//        console.output("https://" + sslConfig.hostname, style: .custom(.cyan), newLine: false)
//        console.output(":" + sslConfig.port.description, style: .custom(.cyan))
//        
//        // bind, listen, and start accepting
//        try tcp.start(
//            hostname: sslConfig.hostname,
//            port: sslConfig.port,
//            backlog: config.backlog
//        )
//        
//        strongRef = tcp
//    }
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
//
///// The EngineServer's SSL configuration
//public struct EngineServerSSLConfig {
//    /// Host name the SSL server will bind to.
//    public var hostname: String
//
//    /// The SSL settings (such as the certificate)
//    public var sslSettings: SSLServerSettings
//
//    /// The port to bind SSL to
//    public var port: UInt16
//
//    public init(settings: SSLServerSettings) {
//        self.hostname = "localhost"
//        self.sslSettings = settings
//        self.port = 443
//    }
//}
//
//
//final class FutureMapStream<I, O>: Async.Stream {
//    public typealias Input = I
//    public typealias Output = O
//
//    public typealias Closure = ((I) throws -> Future<O>)
//
//    private let closure: Closure
//
//    let outputStream = BasicStream<O>()
//
//    public func onInput(_ input: I) {
//        do {
//            try closure(input).do(outputStream.onInput).catch(outputStream.onError)
//        } catch {
//            outputStream.onError(error)
//        }
//    }
//
//    public func onError(_ error: Error) {
//        outputStream.onError(error)
//    }
//
//    public func onOutput<I>(_ input: I) where I : Async.InputStream, O == I.Input {
//        outputStream.onOutput(input)
//    }
//
//    public func close() {
//        outputStream.close()
//    }
//
//    public func onClose(_ onClose: ClosableStream) {
//        outputStream.onClose(onClose)
//    }
//
//    public init(_ closure: @escaping Closure) {
//        self.closure = closure
//    }
//}

//extension Async.OutputStream {
//    typealias ThenClosure<T> = ((Output) throws -> Future<T>)
//
//    func then<T>(_ closure: @escaping ThenClosure<T>) -> FutureMapStream<Output, T> {
//        return FutureMapStream(closure)
//    }
//}

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
    // public var ssl: EngineServerSSLConfig?

    /// Creates a new engine server config
    public init(
        hostname: String = "localhost",
        port: UInt16 = 8080,
        workerCount: Int = 8
    ) {
        self.hostname = hostname
        self.port = port
        self.workerCount = workerCount
        self.backlog = 4096
        self.maxConnectionsPerIP = 128
        // self.ssl = nil
    }
}
