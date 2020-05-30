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
        /// Socket path the server will bind to. If specified, the hostname and port will not be used to bind the server.
        public var unixDomainSocketPath: String?
        
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
            socketPath: String? = nil,
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
            self.unixDomainSocketPath = socketPath
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
        // clear out the unix domain socket path if a new hostname/port is provided so it won't be used
        if hostname != nil || port != nil {
            configuration.unixDomainSocketPath = nil
        }
        
        try start(with: configuration)
    }
    
    public func start(socketPath: String) throws {
        // override the socket path to bind to
        var configuration = self.configuration
        configuration.unixDomainSocketPath = socketPath
        
        try start(with: configuration)
    }
    
    private func start(with configuration: Configuration) throws {
        // print starting message
        let scheme = configuration.tlsConfiguration == nil ? "http" : "https"
        let address: String
        if let socketPath = configuration.unixDomainSocketPath {
            address = "\(scheme)+unix: \(socketPath)"
        } else {
            address = "\(scheme)://\(configuration.hostname):\(configuration.port)"
        }
        
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
    let configuration: HTTPServer.Configuration
    
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
                        tlsHandler = NIOSSLServerHandler(context: sslContext)
                    } catch {
                        configuration.logger.error("Could not configure TLS: \(error)")
                        return channel.close(mode: .all)
                    }
                    return channel.pipeline.addHandler(tlsHandler).flatMap { _ in
                        channel.configureHTTP2SecureUpgrade(h2ChannelConfigurator: { channel in
                            channel.configureHTTP2Pipeline(
                                mode: .server,
                                inboundStreamInitializer: { channel in
                                    channel.pipeline.addVaporHTTP2Handlers(
                                        application: application!,
                                        responder: responder,
                                        configuration: configuration
                                    )
                                }
                            ).map { _ in }
                        }, http1ChannelConfigurator: { channel in
                            channel.pipeline.addVaporHTTP1Handlers(
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
        
        // Check if a socket path has been configured, and use it if it has been.
        if let socketPath = configuration.unixDomainSocketPath {
            return prepareSocketFileForBinding(
                for: configuration,
                with: application.eventLoopGroup.next(),
                in: application.threadPool
            ).flatMap {
                return bootstrap.bind(unixDomainSocketPath: socketPath)
            }.map { channel in
                return .init(
                    channel: channel,
                    quiesce: quiesce,
                    configuration: configuration
                )
            }.flatMapErrorThrowing { error -> HTTPServerConnection in
                quiesce.initiateShutdown(promise: nil)
                
                // Transform `bind(descriptor:ptr:bytes:): Address already in use (errno: 48)`/`No such file or directory (errno: 2)` into a form the user can test for
                switch error as? IOError {
                case .some(let io) where io.errnoCode == EADDRINUSE: throw UnixDomainSocketPathError.socketInUse(io)
                case .some(let io) where io.errnoCode == ENOENT: throw UnixDomainSocketPathError.noSuchDirectory(io)
                default: throw error
                }
            }
        }
        
        // Fallback to binding the server to a host name and port.
        return bootstrap.bind(host: configuration.hostname, port: configuration.port).map { channel in
            return .init(
                channel: channel,
                quiesce: quiesce,
                configuration: configuration
            )
        }.flatMapErrorThrowing { error -> HTTPServerConnection in
            quiesce.initiateShutdown(promise: nil)
            throw error
        }
    }
    
    init(channel: Channel, quiesce: ServerQuiescingHelper, configuration: HTTPServer.Configuration) {
        self.channel = channel
        self.quiesce = quiesce
        self.configuration = configuration
    }
    
    func close() -> EventLoopFuture<Void> {
        let promise = self.channel.eventLoop.makePromise(of: Void.self)
        self.channel.eventLoop.scheduleTask(in: .seconds(10)) {
            promise.fail(Abort(.internalServerError, reason: "Server stop took too long."))
        }
        self.quiesce.initiateShutdown(promise: promise)
        do { // remove the socket file if it exists. This is ok to block since we are shutting down, and are not in an event loop
            try removeSocketFileIfPresent(for: configuration)
        } catch {
            promise.fail(error)
        }
        return promise.futureResult
    }
    
    var onClose: EventLoopFuture<Void> {
        self.channel.closeFuture
    }
    
    deinit {
        assert(!self.channel.isActive, "HTTPServerConnection deinitialized without calling shutdown()")
    }
}

/// Check for and remove a previously established unix domain socket file if one exists, as is standard practice for unix services.
/// - Parameters:
///   - configuration: A configuration with a socket path and logger.
///   - eventLoop: An event loop to report the future on.
///   - threadPool: A thread pool to use when performing IO.
/// - Returns: A future representing the completion of the necessary checks.
private func prepareSocketFileForBinding(for configuration: HTTPServer.Configuration, with eventLoop: EventLoop, in threadPool: NIOThreadPool) -> EventLoopFuture<Void> {
    return threadPool.runIfActive(eventLoop: eventLoop) {
        try removeSocketFileIfPresent(for: configuration)
    }
}

/// Check for and remove a unix domain socket file specified by the configuration if one exists. **This call is blocking.**
/// - Parameters:
///   - configuration: A configuration with a socket path and logger.
/// - Returns: A future representing the completion of the necessary checks.
/// - Throws: `UnixDomainSocketPathError` if the file exists and cannot be removed.
private func removeSocketFileIfPresent(for configuration: HTTPServer.Configuration) throws {
    // If there is no socket path configured, don't do anything and report success. This will be called every-time on server shutdown.
    guard let socketPath = configuration.unixDomainSocketPath else {
        return
    }
    
    var socketFileStat = stat()
    let statResults = lstat(socketPath, &socketFileStat)
    
    // Since we only want to continue if there is a socket file, stop here if an error occurred with stat().
    guard statResults == 0 else {
        let statError = errno
        
        if statError == ENOENT {
            // If stat() failed because a file doesn't exist, then don't do anything and report success — the socket file won't need to be removed.
            return
        }
        
        // If stat reports another error, we likely can't remove the file either, which means NIO will fail when binding, so tell the user by logging it so they can take action.
        configuration.logger.critical("Could not access an existing socket file located at \(socketPath): POSIX Error \(statError). Please remove this file in order to start the server.")
        throw UnixDomainSocketPathError.inaccessible(IOError(errnoCode: statError, reason: "Could not access an existing socket file located at \(socketPath)"))
    }
    
    let mode = socketFileStat.st_mode
    
    // We only want to remove a socket file if it is actually a socket file - the user may have mistyped something, and it would be unfortunate for them to lose anything important otherwise.
    guard mode & S_IFSOCK == S_IFSOCK else {
        // A different type of file was found, so tell the user by logging it so they can take action.
        configuration.logger.notice("An item at \(socketPath) already exists, but it is not a socket file. The socket file must not already exist before binding the server to a unix domain socket path.")
        throw UnixDomainSocketPathError.unsupportedFile(mode, "An item at \(socketPath) already exists, but it is not a socket file")
    }
    
    // The file exists, and is a socket file, so try to unlink it.
    guard unlink(socketPath) == 0 else {
        // If an error occurs during unlink, NIO will fail when binding, so report the error.
        throw UnixDomainSocketPathError.couldNotRemove(IOError(errnoCode: errno, reason: "Could not remove an existing socket file located at \(socketPath)"))
    }
    
    // unlink() reported success, so NIO should be able to bind to the path now.
}

final class HTTPServerErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Never
    let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.logger.debug("Unhandled HTTP server error: \(error)")
        context.close(mode: .output, promise: nil)
    }
}

extension ChannelPipeline {
    func addVaporHTTP2Handlers(
        application: Application,
        responder: Responder,
        configuration: HTTPServer.Configuration
    ) -> EventLoopFuture<Void> {
        // create server pipeline array
        var handlers: [ChannelHandler] = []
        
        let http2 = HTTP2FramePayloadToHTTP1ServerCodec()
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
        let handler = HTTPServerHandler(responder: responder, logger: application.logger)
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
        let handler = HTTPServerHandler(responder: responder, logger: application.logger)

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
