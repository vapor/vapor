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
        
        /// When `true`, can prevent errors re-binding to a socket after successive server restarts.
        public var reuseAddress: Bool
        
        /// When `true`, OS will attempt to minimize TCP packet delay.
        public var tcpNoDelay: Bool

        /// Response compression configuration.
        public var responseCompression: CompressionConfiguration

        /// Supported HTTP compression options.
        public struct CompressionConfiguration {
            /// Disables compression. This is the default.
            public static var disabled: Self {
                .init(storage: .disabled)
            }

            /// Enables compression with default configuration.
            public static var enabled: Self {
                .enabled(initialByteBufferCapacity: 1024)
            }

            /// Enables compression with custom configuration.
            public static func enabled(
                initialByteBufferCapacity: Int
            ) -> Self {
                .init(storage: .enabled(
                    initialByteBufferCapacity: initialByteBufferCapacity
                ))
            }

            enum Storage {
                case disabled
                case enabled(initialByteBufferCapacity: Int)
            }

            var storage: Storage
        }

        /// Request decompression configuration.
        public var requestDecompression: DecompressionConfiguration

        /// Supported HTTP decompression options.
        public struct DecompressionConfiguration {
            /// Disables decompression. This is the default option.
            public static var disabled: Self {
                .init(storage: .disabled)
            }

            /// Enables decompression with default configuration.
            public static var enabled: Self {
                .enabled(limit: .ratio(10))
            }

            /// Enables decompression with custom configuration.
            public static func enabled(
                limit: NIOHTTPDecompression.DecompressionLimit
            ) -> Self {
                .init(storage: .enabled(limit: limit))
            }

            enum Storage {
                case disabled
                case enabled(limit: NIOHTTPDecompression.DecompressionLimit)
            }

            var storage: Storage
        }
        
        /// When `true`, HTTP server will support pipelined requests.
        public var supportPipelining: Bool
        
        public var supportVersions: Set<HTTPVersionMajor>
        
        public var tlsConfiguration: TLSConfiguration?
        
        /// If set, this name will be serialized as the `Server` header in outgoing responses.
        public var serverName: String?
        
        /// Any uncaught server or responder errors will go here.
        public var logger: Logger

        public init(
            hostname: String = "127.0.0.1",
            port: Int = 8080,
            backlog: Int = 256,
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = true,
            responseCompression: CompressionConfiguration = .disabled,
            requestDecompression: DecompressionConfiguration = .disabled,
            supportPipelining: Bool = false,
            supportVersions: Set<HTTPVersionMajor>? = nil,
            tlsConfiguration: TLSConfiguration? = nil,
            serverName: String? = nil,
            logger: Logger? = nil
        ) {
            self.hostname = hostname
            self.port = port
            self.backlog = backlog
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.responseCompression = responseCompression
            self.requestDecompression = requestDecompression
            self.supportPipelining = supportPipelining
            if let supportVersions = supportVersions {
                self.supportVersions = supportVersions
            } else {
                self.supportVersions = tlsConfiguration == nil ? [.one] : [.one, .two]
            }
            self.tlsConfiguration = tlsConfiguration
            self.serverName = serverName
            self.logger = logger ?? Logger(label: "codes.vapor.http-server")
        }
    }
    
    public var onShutdown: EventLoopFuture<Void> {
        guard let connection = self.connection else {
            fatalError("Server has not started yet")
        }
        return connection.channel.closeFuture
    }

    private let responder: Responder
    private let configuration: Configuration
    private let eventLoopGroup: EventLoopGroup
    
    private var connection: HTTPServerConnection?
    private var didShutdown: Bool
    private var didStart: Bool

    private var application: Application
    
    init(
        application: Application,
        responder: Responder,
        configuration: Configuration,
        on eventLoopGroup: EventLoopGroup
    ) {
        self.application = application
        self.responder = responder
        self.configuration = configuration
        self.eventLoopGroup = eventLoopGroup
        self.didStart = false
        self.didShutdown = false
    }
    
    public func start(hostname: String?, port: Int?) throws {
        // determine which hostname / port to bind to
        var configuration = self.configuration
        configuration.hostname = hostname ?? configuration.hostname
        configuration.port = port ?? configuration.port

        // print starting message
        let scheme = configuration.tlsConfiguration == nil ? "http" : "https"
        let address = "\(scheme)://\(configuration.hostname):\(configuration.port)"
        self.configuration.logger.notice("Server starting on \(address)")

        // start the actual HTTPServer
        self.connection = try HTTPServerConnection.start(
            application: self.application,
            responder: self.responder,
            configuration: configuration,
            on: self.eventLoopGroup
        ).wait()

        self.didStart = true
    }
    
    public func shutdown() {
        guard let connection = self.connection else {
            return
        }
        self.configuration.logger.debug("Requesting HTTP server shutdown")
        do {
            try connection.close().wait()
        } catch {
            self.configuration.logger.error("Could not stop HTTP server: \(error)")
        }
        self.configuration.logger.debug("HTTP server shutting down")
        self.didShutdown = true
    }
    
    deinit {
        assert(!self.didStart || self.didShutdown, "HTTPServer did not shutdown before deinitializing")
    }
}

private final class HTTPServerConnection {
    let channel: Channel
    let quiesce: ServerQuiescingHelper
    
    static func start(
        application: Application,
        responder: Responder,
        configuration: HTTPServer.Configuration,
        on eventLoopGroup: EventLoopGroup
    ) -> EventLoopFuture<HTTPServerConnection> {
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
            .childChannelInitializer { [weak application] channel in
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
                        configuration.logger.error("Could not configure TLS: \(error)")
                        return channel.close(mode: .all)
                    }
                    return channel.pipeline.addHandler(tlsHandler).flatMap { _ in
                        return channel.configureHTTP2SecureUpgrade(h2ChannelConfigurator: { channel in
                            return channel.configureHTTP2Pipeline(
                                mode: .server,
                                inboundStreamStateInitializer: { (channel, streamID) in
                                    return channel.pipeline.addVaporHTTP2Handlers(
                                        application: application!,
                                        responder: responder,
                                        configuration: configuration,
                                        streamID: streamID
                                    )
                                }
                            ).map { _ in }
                        }, http1ChannelConfigurator: { channel in
                            return channel.pipeline.addVaporHTTP1Handlers(
                                application: application!,
                                responder: responder,
                                configuration: configuration
                            )
                        })
                    }
                } else {
                    guard !configuration.supportVersions.contains(.two) else {
                        fatalError("Plaintext HTTP/2 (h2c) not yet supported.")
                    }
                    return channel.pipeline.addVaporHTTP1Handlers(
                        application: application!,
                        responder: responder,
                        configuration: configuration
                    )
                }
            }
            
            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: configuration.tcpNoDelay ? SocketOptionValue(1) : SocketOptionValue(0))
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: configuration.reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        
        return bootstrap.bind(host: configuration.hostname, port: configuration.port).map { channel in
            return .init(channel: channel, quiesce: quiesce)
        }.flatMapErrorThrowing { error -> HTTPServerConnection in
            quiesce.initiateShutdown(promise: nil)
            throw error
        }
    }
    
    init(channel: Channel, quiesce: ServerQuiescingHelper) {
        self.channel = channel
        self.quiesce = quiesce
    }
    
    func close() -> EventLoopFuture<Void> {
        let promise = self.channel.eventLoop.makePromise(of: Void.self)
        self.channel.eventLoop.scheduleTask(in: .seconds(10)) {
            promise.fail(Abort(.internalServerError, reason: "Server stop took too long."))
        }
        self.quiesce.initiateShutdown(promise: promise)
        return promise.futureResult
    }
    
    var onClose: EventLoopFuture<Void> {
        self.channel.closeFuture
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
        context.close(mode: .output, promise: nil)
    }
}

private extension ChannelPipeline {
    func addVaporHTTP2Handlers(
        application: Application,
        responder: Responder,
        configuration: HTTPServer.Configuration,
        streamID: HTTP2StreamID
    ) -> EventLoopFuture<Void> {
        // create server pipeline array
        var handlers: [ChannelHandler] = []
        
        let http2 = HTTP2ToHTTP1ServerCodec(streamID: streamID)
        handlers.append(http2)
        
        // add NIO -> HTTP request decoder
        let serverReqDecoder = HTTPServerRequestDecoder(
            application: application
        )
        handlers.append(serverReqDecoder)
        
        // add NIO -> HTTP response encoder
        let serverResEncoder = HTTPServerResponseEncoder(
            serverHeader: configuration.serverName,
            dateCache: .eventLoop(self.eventLoop)
        )
        handlers.append(serverResEncoder)
        
        // add server request -> response delegate
        let handler = HTTPServerHandler(responder: responder)
        handlers.append(handler)
        
        return self.addHandlers(handlers).flatMap {
            self.addHandler(HTTPServerErrorHandler(logger: configuration.logger))
        }
    }
    
    func addVaporHTTP1Handlers(
        application: Application,
        responder: Responder,
        configuration: HTTPServer.Configuration
    ) -> EventLoopFuture<Void> {
        // create server pipeline array
        var handlers: [RemovableChannelHandler] = []
        
        // configure HTTP/1
        // add http parsing and serializing
        let httpResEncoder = HTTPResponseEncoder()
        let httpReqDecoder = ByteToMessageHandler(HTTPRequestDecoder(
            leftOverBytesStrategy: .forwardBytes
        ))
        handlers += [httpResEncoder, httpReqDecoder]
        
        // add pipelining support if configured
        if configuration.supportPipelining {
            let pipelineHandler = HTTPServerPipelineHandler()
            handlers.append(pipelineHandler)
        }
        
        // add response compressor if configured
        switch configuration.responseCompression.storage {
        case .enabled(let initialByteBufferCapacity):
            let responseCompressionHandler = HTTPResponseCompressor(
                initialByteBufferCapacity: initialByteBufferCapacity
            )
            handlers.append(responseCompressionHandler)
        case .disabled:
            break
        }

        // add request decompressor if configured
        switch configuration.requestDecompression.storage {
        case .enabled(let limit):
            let requestDecompressionHandler = NIOHTTPRequestDecompressor(
                limit: limit
            )
            handlers.append(requestDecompressionHandler)
        case .disabled:
            break
        }

        // add NIO -> HTTP response encoder
        let serverResEncoder = HTTPServerResponseEncoder(
            serverHeader: configuration.serverName,
            dateCache: .eventLoop(self.eventLoop)
        )
        handlers.append(serverResEncoder)
        
        // add NIO -> HTTP request decoder
        let serverReqDecoder = HTTPServerRequestDecoder(
            application: application
        )
        handlers.append(serverReqDecoder)
        // add server request -> response delegate
        let handler = HTTPServerHandler(responder: responder)

        // add HTTP upgrade handler
        let upgrader = HTTPServerUpgradeHandler(
            httpRequestDecoder: httpReqDecoder,
            httpHandlers: handlers + [handler]
        )

        handlers.append(upgrader)
        handlers.append(handler)
        
        // wait to add delegate as final step
        return self.addHandlers(handlers).flatMap {
            self.addHandler(HTTPServerErrorHandler(logger: configuration.logger))
        }
    }
}
