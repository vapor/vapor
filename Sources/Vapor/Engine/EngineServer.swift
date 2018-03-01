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
        print(Foundation.Thread.current.name)
//        let tcpServer = try TCPServer(socket: TCPSocket(isNonBlocking: true, shouldReuseAddress: true))
        // leaking, probably because of client capturing itself in closure
        // tcpServer.willAccept = PeerValidator(maxConnectionsPerIP: config.maxConnectionsPerIP).willAccept
        
//        let console = try container.make(Console.self, for: EngineServer.self)
//        let logger = try container.make(Logger.self, for: EngineServer.self)

        let group = MultiThreadedEventLoopGroup(numThreads: System.coreCount)
        let threadPool = BlockingIOThreadPool(numberOfThreads: 1)
        threadPool.start()

        let fileIO = NonBlockingFileIO(threadPool: threadPool)
//        let subContainer = container.subContainer(on: container)
//        let responder = try subContainer.make(Responder.self, for: EngineServer.self)

        let bootstrap = ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                channel.pipeline.addHTTPServerHandlers().then {
                    channel.pipeline.add(handler: EngineResponder())
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

final class EngineResponder: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
//    let responder: Responder
//    let container: Container

//    init(container: Container, responder: Responder) {
//        self.container = container
//        self.responder = responder
//    }

    init() {

        print(#function)
    }

    /// Called when some data has been read from the remote peer.
    ///
    /// This should call `ctx.fireChannelRead` to forward the operation to the next `_ChannelInboundHandler` in the `ChannelPipeline` if you want to allow the next handler to also handle the event.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ChannelHandler` belongs to.
    ///     - data: The data read from the remote peer, wrapped in a `NIOAny`.
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        print(#function)
        print(ctx)
        print(data)
        let reqPart = unwrapInboundIn(data)
//        if let handler = self.handler {
//            handler(ctx, reqPart)
//            return
//        }
        print(reqPart)
    }

    /// Called when the `Channel` has successfully registered with its `EventLoop` to handle I/O.
    ///
    /// This should call `ctx.fireChannelRegistered` to forward the operation to the next `_ChannelInboundHandler` in the `ChannelPipeline` if you want to allow the next handler to also handle the event.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ChannelHandler` belongs to.
    func channelRegistered(ctx: ChannelHandlerContext) {
        print(#function)
    }

    /// Called when the `Channel` has unregistered from its `EventLoop`, and so will no longer be receiving I/O events.
    ///
    /// This should call `ctx.fireChannelUnregistered` to forward the operation to the next `_ChannelInboundHandler` in the `ChannelPipeline` if you want to allow the next handler to also handle the event.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ChannelHandler` belongs to.
    func channelUnregistered(ctx: ChannelHandlerContext) {
        print(#function)
    }

    /// Called when the `Channel` has become active, and is able to send and receive data.
    ///
    /// This should call `ctx.fireChannelActive` to forward the operation to the next `_ChannelInboundHandler` in the `ChannelPipeline` if you want to allow the next handler to also handle the event.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ChannelHandler` belongs to.
    func channelActive(ctx: ChannelHandlerContext) {
        print(#function)
    }

    /// Called when the `Channel` has become inactive and is no longer able to send and receive data`.
    ///
    /// This should call `ctx.fireChannelInactive` to forward the operation to the next `_ChannelInboundHandler` in the `ChannelPipeline` if you want to allow the next handler to also handle the event.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ChannelHandler` belongs to.
    func channelInactive(ctx: ChannelHandlerContext) {
        print(#function)
    }

    /// Called when the `Channel` has completed its current read loop, either because no more data is available to read from the transport at this time, or because the `Channel` needs to yield to the event loop to process other I/O events for other `Channel`s.
    /// If `ChannelOptions.autoRead` is `false` no futher read attempt will be made until `ChannelHandlerContext.read` or `Channel.read` is explicitly called.
    ///
    /// This should call `ctx.fireChannelReadComplete` to forward the operation to the next `_ChannelInboundHandler` in the `ChannelPipeline` if you want to allow the next handler to also handle the event.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ChannelHandler` belongs to.
    func channelReadComplete(ctx: ChannelHandlerContext) {
        print(#function)
    }

    /// The writability state of the `Channel` has changed, either because it has buffered more data than the writability high water mark, or because the amount of buffered data has dropped below the writability low water mark.
    /// You can check the state with `Channel.isWritable`.
    ///
    /// This should call `ctx.fireChannelWritabilityChanged` to forward the operation to the next `_ChannelInboundHandler` in the `ChannelPipeline` if you want to allow the next handler to also handle the event.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ChannelHandler` belongs to.
    func channelWritabilityChanged(ctx: ChannelHandlerContext) {
        print(#function)
    }

    /// Called when a user inbound event has been triggered.
    ///
    /// This should call `ctx.fireUserInboundEventTriggered` to forward the operation to the next `_ChannelInboundHandler` in the `ChannelPipeline` if you want to allow the next handler to also handle the event.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ChannelHandler` belongs to.
    ///     - event: The event.
    func userInboundEventTriggered(ctx: ChannelHandlerContext, event: Any) {
        print(#function)
    }

    /// An error was encountered earlier in the inbound `ChannelPipeline`.
    ///
    /// This should call `ctx.fireErrorCaught` to forward the operation to the next `_ChannelInboundHandler` in the `ChannelPipeline` if you want to allow the next handler to also handle the error.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ChannelHandler` belongs to.
    ///     - error: The `Error` that was encountered.
    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        print(#function)
    }

    /// Called when this `ChannelHandler` is added to the `ChannelPipeline`.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ChannelHandler` belongs to.
    func handlerAdded(ctx: ChannelHandlerContext) {
        print(#function)
    }

    /// Called when this `ChannelHandler` is removed from the `ChannelPipeline`.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ChannelHandler` belongs to.
    func handlerRemoved(ctx: ChannelHandlerContext) {
        print(#function)
    }

//    func respond(to httpRequest: HTTPRequest, on worker: Worker) throws -> Future<HTTPResponse> {
//        fatalError()
//        return Future.flatMap {
//            let req = Request(http: httpRequest, using: self.container)
//            return try self.responder.respond(to: req)
//                .map(to: HTTPResponse.self) { $0.http }
//        }
//    }
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
