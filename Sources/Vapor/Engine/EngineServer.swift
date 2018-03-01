import Async
import Bits
import Console
import Command
import Debugging
import Dispatch
import Foundation
//import HTTP
import Service
//import TCP
//import TLS

/// A TCP based server with HTTP parsing and serialization pipeline.
public final class EngineServer: Server, Service {
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
    public func start() throws {
//        let tcpServer = try TCPServer(socket: TCPSocket(isNonBlocking: true, shouldReuseAddress: true))
        // leaking, probably because of client capturing itself in closure
        // tcpServer.willAccept = PeerValidator(maxConnectionsPerIP: config.maxConnectionsPerIP).willAccept
        
//        let console = try container.make(Console.self, for: EngineServer.self)
//        let logger = try container.make(Logger.self, for: EngineServer.self)


        let group = MultiThreadedEventLoopGroup(numThreads: 1) // System.coreCount
        let bootstrap = ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                let subContainer = self.container.subContainer(on: wrap(channel.eventLoop))
                let responder = try! subContainer.make(Responder.self, for: EngineServer.self)
                // re-use subcontainer for an event loop here
                return channel.pipeline.addHTTPServerHandlers().then {
                    channel.pipeline.add(handler: HTTPHandler(container: subContainer, responder: responder))
                }
            }

            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)

//        defer {
//            try! group.syncShutdownGracefully()
//        }

        let channel = try bootstrap.bind(host: "::1", port: Int(config.port)).wait()

        print("http://" + channel.localAddress!.description)
//        console.print("Server started on ", newLine: false)
//        console.output("http://" + channel.localAddress!.description, style: .init(color: .cyan), newLine: false)
//        console.output(":" + config.port.description, style: .init(color: .cyan))

        try channel.closeFuture.wait()

        
//        for i in 1...config.workerCount {
//            let eventLoop = try DefaultEventLoop(label: "codes.vapor.engine.server.worker.\(i)")
//            let subContainer = self.container.subContainer(on: eventLoop)
//            let subResponder = try subContainer.make(Responder.self, for: EngineServer.self)
//            let responder = EngineResponder(container: subContainer, responder: subResponder)
//            let acceptStream = tcpServer.stream(on: eventLoop).map(to: TCPSocketStream.self) {
//                $0.socket.stream(on: eventLoop) { sink, error in
//                    logger.reportError(error, as: "Server Error")
//                    sink.close()
//                }
//            }
//
//            let server = HTTPServer(
//                acceptStream: acceptStream,
//                worker: eventLoop,
//                responder: responder
//            )
//
//            server.onError = { error in
//                logger.reportError(error, as: "Server Error")
//            }
//
//            // non-blocking main thread run
//            Thread.async { eventLoop.runLoop() }
//        }
//
//        // bind, listen, and start accepting
//        try tcpServer.start(
//            hostname: config.hostname,
//            port: config.port,
//            backlog: config.backlog
//        )

        // container.eventLoop.runLoop()
    }
}

enum HTTPHandlerState {
    case ready
    case parsingBody(HTTPRequestHead, Data?)
}

final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let container: Container
    private let responder: Responder

    private var state: HTTPHandlerState

    public init(container: Container, responder: Responder) {
        print(#function)
        self.container = container
        self.responder = responder
        self.state = .ready
    }

    func handleInfo(ctx: ChannelHandlerContext, request: HTTPServerRequestPart) {
        print(#function)
    }

    func handleEcho(ctx: ChannelHandlerContext, request: HTTPServerRequestPart) {
        print(#function)
    }

    func handleEcho(ctx: ChannelHandlerContext, request: HTTPServerRequestPart, balloonInMemory: Bool = false) {
        print(#function)
    }

    func handleJustWrite(ctx: ChannelHandlerContext, request: HTTPServerRequestPart, statusCode: HTTPResponseStatus = .ok, string: String, trailer: (String, String)? = nil, delay: TimeAmount = .nanoseconds(0)) {
        print(#function)
    }

    func handleContinuousWrites(ctx: ChannelHandlerContext, request: HTTPServerRequestPart) {
        print(#function)
    }

    func handleMultipleWrites(ctx: ChannelHandlerContext, request: HTTPServerRequestPart, strings: [String], delay: TimeAmount) {
        print(#function)
    }

    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        print(ctx.eventLoop)
        let req = unwrapInboundIn(data)
        print(req)
        switch req {
        case .head(let head):
            switch state {
            case .ready: state = .parsingBody(head, nil)
            case .parsingBody: fatalError()
            }
        case .body(var body):
            switch state {
            case .ready: fatalError()
            case .parsingBody(let head, let existingData):
                let data: Data
                if var existing = existingData {
                    existing += body.readData(length: body.readableBytes) ?? Data()
                    data = existing
                } else {
                    data = body.readData(length: body.readableBytes) ?? Data()
                }
                state = .parsingBody(head, data)
            }
        case .end(let tailHeaders):
            assert(tailHeaders == nil)
            switch state {
            case .ready: fatalError()
            case .parsingBody(let head, let data):
                let httpReq = HTTPRequest(
                    method: head.method,
                    uri: head.uri,
                    version: head.version,
                    headers: head.headers,
                    body: data
                )
                let req = Request(http: httpReq, using: container)
                try! responder.respond(to: req).do { res in
                    var headers = res.http.headers
                    if let body = res.http.body {
                        headers.replaceOrAdd(name: "Content-Length", value: body.count.description)
                    }
                    let httpHead = HTTPResponseHead.init(version: res.http.version, status: res.http.status, headers: headers)
                    ctx.write(self.wrapOutboundOut(.head(httpHead)), promise: nil)
                    if let body = res.http.body {
                        var buffer = ByteBufferAllocator().buffer(capacity: body.count)
                        buffer.write(bytes: body)
                        ctx.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
                    }
                    ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                    ctx.channel.close(promise: nil)
                }.catch { error in
                    fatalError("\(error)")
                }
            }
        }
    }

    func channelReadComplete(ctx: ChannelHandlerContext) {
        print(#function)
    }

    func handlerAdded(ctx: ChannelHandlerContext) {
        print(#function)
        print(ctx.eventLoop)
        print(ctx.channel)
        print(ctx.name)
        print(ctx.pipeline)
    }
}

extension Logger {
    func reportError(_ error: Error, as label: String) {
        var string = ""
        if let debuggable = error as? Debuggable {
            string += debuggable.fullIdentifier
            string += ": "
            string += debuggable.reason
        } else {
            string += "\(error)"
        }
        if let debuggable = error as? Debuggable {
            if let source = debuggable.sourceLocation {
                self.error(string,
                   file: source.file,
                   function: source.function,
                   line: source.line,
                   column: source.column
                )
            } else {
                self.error(string)
            }
            if debuggable.suggestedFixes.count > 0 {
                self.debug("Suggested fixes for \(debuggable.fullIdentifier): " + debuggable.suggestedFixes.joined(separator: " "))
            }
            if debuggable.possibleCauses.count > 0 {
                self.debug("Possible causes for \(debuggable.fullIdentifier): " + debuggable.possibleCauses.joined(separator: " "))
            }
        } else {
            self.error(string)
        }
    }
}

/// Engine server config struct.
public struct EngineServerConfig: Service {
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
        hostname: String,
        port: UInt16,
        backlog: Int32,
        workerCount: Int,
        maxConnectionsPerIP: Int
    ) {
        self.hostname = hostname
        self.port = port
        self.workerCount = workerCount
        self.backlog = backlog
        self.maxConnectionsPerIP = maxConnectionsPerIP
        // self.ssl = nil
    }
}

extension EngineServerConfig {
    /// Detects `EngineServerConfig` from the environment.
    public static func detect(
        hostname: String = "localhost",
        port: UInt16 = 8080,
        backlog: Int32 = 4096,
        workerCount: Int = ProcessInfo.processInfo.activeProcessorCount,
        maxConnectionsPerIP: Int = 128
    ) throws -> EngineServerConfig {
        return try EngineServerConfig(
            hostname: CommandInput.commandLine.parse(option: .value(name: "hostname")) ?? hostname,
            port: CommandInput.commandLine.parse(option: .value(name: "port")).flatMap(UInt16.init) ?? port,
            backlog: backlog,
            workerCount: workerCount,
            maxConnectionsPerIP: maxConnectionsPerIP
        )
    }
}
