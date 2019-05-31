import NIO
import NIOExtras
import NIOHTTP1
import NIOHTTP2
import NIOHTTPCompression
import NIOSSL

public enum HTTPVersionMajor: Equatable, Hashable {
    case one
    case two
}

public final class HTTPServer: Server {
    /// Engine server config struct.
    ///
    ///     let serverConfig = HTTPServerConfig.default(port: 8123)
    ///     services.register(serverConfig)
    ///
    public struct Configuration {
        /// Host name the server will bind to.
        public var hostname: String
        
        /// Port the server will bind to.
        public var port: Int
        
        /// Listen backlog.
        public var backlog: Int
        
        /// Requests containing bodies larger than this maximum will be rejected, closing the connection.
        public var maxBodySize: Int
        
        /// When `true`, can prevent errors re-binding to a socket after successive server restarts.
        public var reuseAddress: Bool
        
        /// When `true`, OS will attempt to minimize TCP packet delay.
        public var tcpNoDelay: Bool
        
        /// Number of webSocket maxFrameSize.
        public var webSocketMaxFrameSize: Int
        
        /// When `true`, HTTP server will support gzip and deflate compression.
        public var supportCompression: Bool
        
        /// When `true`, HTTP server will support pipelined requests.
        public var supportPipelining: Bool
        
        public var supportVersions: Set<HTTPVersionMajor>
        
        public var tlsConfiguration: TLSConfiguration?
        
        /// If set, this name will be serialized as the `Server` header in outgoing responses.
        public var serverName: String?
        
        /// Any uncaught server or responder errors will go here.
        public var errorHandler: (Error) -> ()
        
        /// Creates a new `HTTPServerConfig`.
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
        ///     - webSocketMaxFrameSize: Number of webSocket maxFrameSize.
        ///     - supportCompression: When `true`, HTTP server will support gzip and deflate compression.
        ///     - supportPipelining: When `true`, HTTP server will support pipelined requests.
        ///     - serverName: If set, this name will be serialized as the `Server` header in outgoing responses.
        ///     - upgraders: An array of `HTTPProtocolUpgrader` to check for with each request.
        ///     - errorHandler: Any uncaught server or responder errors will go here.
        public init(
            hostname: String = "127.0.0.1",
            port: Int = 8080,
            backlog: Int = 256,
            maxBodySize: Int = 1_000_000,
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = true,
            webSocketMaxFrameSize: Int = 1 << 14,
            supportCompression: Bool = false,
            supportPipelining: Bool = false,
            supportVersions: Set<HTTPVersionMajor>? = nil,
            tlsConfiguration: TLSConfiguration? = nil,
            serverName: String? = nil,
            errorHandler: @escaping (Error) -> () = { _ in }
            ) {
            self.hostname = hostname
            self.port = port
            self.backlog = backlog
            self.maxBodySize = maxBodySize
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.webSocketMaxFrameSize = webSocketMaxFrameSize
            self.supportCompression = supportCompression
            self.supportPipelining = supportPipelining
            if let supportVersions = supportVersions {
                self.supportVersions = supportVersions
            } else {
                self.supportVersions = tlsConfiguration == nil ? [.one] : [.one, .two]
            }
            self.tlsConfiguration = tlsConfiguration
            self.serverName = serverName
            self.errorHandler = errorHandler
        }
    }
    
    public var onShutdown: EventLoopFuture<Void> {
        guard let connection = self.connection else {
            fatalError("Server has not started yet")
        }
        return connection.channel.closeFuture
    }
    
    private let application: Application
    private let configuration: Configuration
    private let responder: HTTPServerResponder
    
    private var connection: HTTPServerConnection?
    private var didShutdown: Bool
    private var didStart: Bool
    
    init(application: Application, configuration: Configuration) {
        self.application = application
        self.configuration = configuration
        self.responder = .init(application: application)
        self.didStart = false
        self.didShutdown = false
    }
    
    public func start(hostname: String?, port: Int?) throws {
        var configuration = self.configuration
        
        // determine which hostname / port to bind to
        configuration.hostname = hostname ?? self.configuration.hostname
        configuration.port = port ?? self.configuration.port
        
        // print starting message
        let scheme = self.configuration.tlsConfiguration == nil ? "http" : "https"
        let address = "\(scheme)://\(configuration.hostname):\(configuration.port)"
        self.application.logger.info("Server starting on \(address)")

        // TODO: consider moving to serve command
        self.application.running = .init(stop: { [unowned self] in
            self.shutdown()
        })
        
        // start the actual HTTPServer
        let connection = HTTPServerConnection.start(
            responder: self.responder,
            configuration: self.configuration,
            on: self.application.eventLoopGroup
        )
        self.connection = try connection.wait()
        self.didStart = true
    }
    
    public func shutdown() {
        guard let connection = self.connection else {
            fatalError("Called shutdown before start")
        }
        self.application.logger.debug("Requesting server shutdown")
        do {
            try connection.close().wait()
        } catch {
            self.application.logger.error("Could not stop server: \(error)")
        }
        self.application.logger.debug("Server shutting down")
        self.didShutdown = true
        self.responder.shutdown()
    }
    
    deinit {
        assert(!self.didStart || self.didShutdown, "HTTPServer did not shutdown before deinitializing")
    }
}

private final class HTTPServerResponder: Responder {
    let application: Application
    private let responderCache: ThreadSpecificVariable<ResponderCache>
    private var containers: [Container]
    
    init(application: Application) {
        self.application = application
        self.responderCache = .init()
        self.containers = []
    }
    
    func respond(to request: Request) -> EventLoopFuture<Response> {
        request.logger.info("\(request.method) \(request.url)")
        if let responder = self.responderCache.currentValue?.responder {
            return responder.respond(to: request)
        } else {
            return application.makeContainer(on: request.eventLoop).flatMapThrowing { container -> Responder in
                self.containers.append(container)
                let responder = try container.make(Responder.self)
                self.responderCache.currentValue = ResponderCache(responder: responder)
                return responder
            }.flatMap { responder in
                return responder.respond(to: request)
            }
        }
    }
    
    func shutdown() {
        let containers = self.containers
        self.containers = []
        for container in containers {
            container.shutdown()
        }
    }
}

private final class ResponderCache {
    var responder: Responder
    init(responder: Responder) {
        self.responder = responder
    }
}

private final class HTTPServerConnection {
    let channel: Channel
    let quiesce: ServerQuiescingHelper
    
    static func start(
        responder: Responder,
        configuration: HTTPServer.Configuration,
        on eventLoopGroup: EventLoopGroup
    ) -> EventLoopFuture<HTTPServerConnection> {
        let logger = Logger(label: "codes.vapor.http-server")
        let quiesce = ServerQuiescingHelper(group: eventLoopGroup)
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: Int32(configuration.backlog))
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: configuration.reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))
            
            // Set handlers that are applied to the Server's channel
            .serverChannelInitializer { channel in
                channel.pipeline.addHandler(quiesce.makeServerChannelHandler(channel: channel))
            }
            
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                // add TLS handlers if configured
                if var tlsConfiguration = configuration.tlsConfiguration {
                    // prioritize http/2
                    if configuration.supportVersions.contains(.two) {
                        tlsConfiguration.applicationProtocols.append("h2")
                    }
                    if configuration.supportVersions.contains(.one) {
                        tlsConfiguration.applicationProtocols.append("http/1.1")
                    }
                    let sslContext: NIOSSLContext
                    let tlsHandler: NIOSSLServerHandler
                    do {
                        sslContext = try NIOSSLContext(configuration: tlsConfiguration)
                        tlsHandler = try NIOSSLServerHandler(context: sslContext)
                    } catch {
                        logger.error("Could not configure TLS: \(error)")
                        return channel.close(mode: .all)
                    }
                    return channel.pipeline.addHandler(tlsHandler).flatMap { (_) -> EventLoopFuture<Void> in
                        return channel.pipeline.configureHTTP2SecureUpgrade(h2PipelineConfigurator: { (pipeline) -> EventLoopFuture<Void> in
                            return channel.configureHTTP2Pipeline(mode: .server, inboundStreamStateInitializer: { (channel, streamID) -> EventLoopFuture<Void> in
                                return channel.pipeline.addVaporHTTP2Handlers(responder: responder, configuration: configuration, streamID: streamID)
                            }).flatMap { (_) -> EventLoopFuture<Void> in
                                return channel.pipeline.addHandler(HTTPServerErrorHandler(logger: logger))
                            }
                        }, http1PipelineConfigurator: { (pipeline) -> EventLoopFuture<Void> in
                            return pipeline.addVaporHTTP1Handlers(responder: responder, configuration: configuration)
                        })
                    }
                } else {
                    guard !configuration.supportVersions.contains(.two) else {
                        fatalError("Plaintext HTTP/2 (h2c) not yet supported.")
                    }
                    return channel.pipeline.addVaporHTTP1Handlers(responder: responder, configuration: configuration)
                }
            }
            
            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: configuration.tcpNoDelay ? SocketOptionValue(1) : SocketOptionValue(0))
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: configuration.reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        // .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: 1)
        
        return bootstrap.bind(host: configuration.hostname, port: configuration.port).map { channel in
            return .init(channel: channel, quiesce: quiesce)
        }
    }
    
    init(channel: Channel, quiesce: ServerQuiescingHelper) {
        self.channel = channel
        self.quiesce = quiesce
    }
    
    func close() -> EventLoopFuture<Void> {
        let promise = channel.eventLoop.makePromise(of: Void.self)
        channel.eventLoop.scheduleTask(in: .seconds(10)) {
            promise.fail(Abort(.internalServerError, reason: "Server stop took too long."))
        }
        quiesce.initiateShutdown(promise: promise)
        return promise.futureResult
    }
    
    var onClose: EventLoopFuture<Void> {
        return channel.closeFuture
    }
    
    deinit {
        assert(!self.channel.isActive, "HTTPServerConnection deinitialized without calling shutdown()")
    }
}

final class HTTPServerErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Never
    let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.logger.error("Unhandled HTTP server error: \(error)")
        context.close(promise: nil)
    }
}

private extension ChannelPipeline {
    func addVaporHTTP2Handlers(responder: Responder, configuration: HTTPServer.Configuration, streamID: HTTP2StreamID) -> EventLoopFuture<Void> {
        // create server pipeline array
        var handlers: [ChannelHandler] = []
        
        let http2 = HTTP2ToHTTP1ServerCodec(streamID: streamID)
        handlers.append(http2)
        
        // add NIO -> HTTP request decoder
        let serverReqDecoder = HTTPServerRequestDecoder(
            maxBodySize: configuration.maxBodySize
        )
        handlers.append(serverReqDecoder)
        
        // add NIO -> HTTP response encoder
        let serverResEncoder = HTTPServerResponseEncoder(
            serverHeader: configuration.serverName,
            dateCache: .eventLoop(self.eventLoop)
        )
        handlers.append(serverResEncoder)
        
        // add server request -> response delegate
        let handler = HTTPServerHandler(
            responder: responder,
            errorHandler: configuration.errorHandler
        )
        handlers.append(handler)
        
        return self.addHandlers(handlers)
    }
    
    func addVaporHTTP1Handlers(responder: Responder, configuration: HTTPServer.Configuration) -> EventLoopFuture<Void> {
        // create server pipeline array
        var handlers: [ChannelHandler] = []
        var otherHTTPHandlers: [RemovableChannelHandler] = []
        
        // configure HTTP/1
        // add http parsing and serializing
        let httpResEncoder = HTTPResponseEncoder()
        let httpReqDecoder = ByteToMessageHandler(HTTPRequestDecoder(
            leftOverBytesStrategy: .forwardBytes
        ))
        handlers += [httpResEncoder, httpReqDecoder]
        otherHTTPHandlers += [httpResEncoder]
        
        // add pipelining support if configured
        if configuration.supportPipelining {
            let pipelineHandler = HTTPServerPipelineHandler()
            handlers.append(pipelineHandler)
            otherHTTPHandlers.append(pipelineHandler)
        }
        
        // add response compressor if configured
        if configuration.supportCompression {
            let compressionHandler = HTTPResponseCompressor()
            handlers.append(compressionHandler)
            otherHTTPHandlers.append(compressionHandler)
        }
        
        // add NIO -> HTTP request decoder
        let serverReqDecoder = HTTPServerRequestDecoder(
            maxBodySize: configuration.maxBodySize
        )
        handlers.append(serverReqDecoder)
        otherHTTPHandlers.append(serverReqDecoder)
        
        // add NIO -> HTTP response encoder
        let serverResEncoder = HTTPServerResponseEncoder(
            serverHeader: configuration.serverName,
            dateCache: .eventLoop(self.eventLoop)
        )
        handlers.append(serverResEncoder)
        otherHTTPHandlers.append(serverResEncoder)
        
        // add server request -> response delegate
        let handler = HTTPServerHandler(
            responder: responder,
            errorHandler: configuration.errorHandler
        )
        otherHTTPHandlers.append(handler)
        
        // add HTTP upgrade handler
        let upgrader = HTTPServerUpgradeHandler(
            httpRequestDecoder: httpReqDecoder,
            otherHTTPHandlers: otherHTTPHandlers
        )
        handlers.append(upgrader)
        
        // wait to add delegate as final step
        handlers.append(handler)
        return self.addHandlers(handlers)
    }
}
