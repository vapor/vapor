import NIO
import NIOExtras
import NIOHTTP1
import NIOHTTP2
import NIOHTTPCompression
import NIOSSL

internal final class HTTPServer {
    let configuration: ServerConfiguration
    let eventLoopGroup: EventLoopGroup
    
    private var channel: Channel?
    private var quiesce: ServerQuiescingHelper?
    
    init(configuration: ServerConfiguration, on eventLoopGroup: EventLoopGroup) {
        self.configuration = configuration
        self.eventLoopGroup = eventLoopGroup
    }
    
    func start(responder: Responder) -> EventLoopFuture<Void> {
        let quiesce = ServerQuiescingHelper(group: eventLoopGroup)
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: Int32(self.configuration.backlog))
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: self.configuration.reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))
            
            // Set handlers that are applied to the Server's channel
            .serverChannelInitializer { channel in
                channel.pipeline.addHandler(quiesce.makeServerChannelHandler(channel: channel))
            }
            
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { [weak self] channel in
                guard let self = self else {
                    fatalError("HTTP server has deinitialized")
                }
                // add TLS handlers if configured
                if var tlsConfig = self.configuration.tlsConfiguration {
                    // prioritize http/2
                    if self.configuration.supportVersions.contains(.two) {
                        tlsConfig.applicationProtocols.append("h2")
                    }
                    if self.configuration.supportVersions.contains(.one) {
                        tlsConfig.applicationProtocols.append("http/1.1")
                    }
                    let sslContext: NIOSSLContext
                    let tlsHandler: NIOSSLServerHandler
                    do {
                        sslContext = try NIOSSLContext(configuration: tlsConfig)
                        tlsHandler = try NIOSSLServerHandler(context: sslContext)
                    } catch {
                        print("Could not configure TLS: \(error)")
                        return channel.close(mode: .all)
                    }
                    return channel.pipeline.addHandler(tlsHandler).flatMap {
                        return channel.pipeline.configureHTTP2SecureUpgrade(h2PipelineConfigurator: { pipeline in
                            return channel.configureHTTP2Pipeline(mode: .server, inboundStreamStateInitializer: { channel, streamID in
                                return channel.pipeline.addHandlers(self.http2Handlers(responder: responder, channel: channel, streamID: streamID))
                            }).flatMap { _ in
                                return channel.pipeline.addHandler(HTTPServerErrorHandler())
                            }
                        }, http1PipelineConfigurator: { pipeline in
                            return pipeline.addHandlers(self.http1Handlers(responder: responder, channel: channel))
                        })
                    }
                } else {
                    guard !self.configuration.supportVersions.contains(.two) else {
                        fatalError("Plaintext HTTP/2 (h2c) not yet supported.")
                    }
                    let handlers = self.http1Handlers(responder: responder, channel: channel)
                    return channel.pipeline.addHandlers(handlers, position: .last)
                }
            }
            
            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: self.configuration.tcpNoDelay ? SocketOptionValue(1) : SocketOptionValue(0))
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: self.configuration.reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        // .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: 1)
        
        return bootstrap.bind(host: self.configuration.hostname, port: self.configuration.port).map { channel in
            self.channel = channel
            self.quiesce = quiesce
        }
    }
    
    public func stop() -> EventLoopFuture<Void> {
        guard let channel = self.channel, let quiesce = self.quiesce else {
            fatalError("Called stop() before start()")
        }
        let promise = channel.eventLoop.makePromise(of: Void.self)
        channel.eventLoop.scheduleTask(in: .seconds(10)) {
            promise.fail(Abort(.internalServerError, reason: "Server stop took too long."))
        }
        quiesce.initiateShutdown(promise: promise)
        return promise.futureResult
    }
    
    public var onClose: EventLoopFuture<Void> {
        guard let channel = self.channel else {
            fatalError("Called onClose before start()")
        }
        return channel.closeFuture
    }
    
    private func http2Handlers(responder: Responder, channel: Channel, streamID: HTTP2StreamID) -> [ChannelHandler] {
        // create server pipeline array
        var handlers: [ChannelHandler] = []
        
        let http2 = HTTP2ToHTTP1ServerCodec(streamID: streamID)
        handlers.append(http2)
        
        // add NIO -> HTTP request decoder
        let serverReqDecoder = HTTPServerRequestDecoder(
            maxBodySize: self.configuration.maxBodySize
        )
        handlers.append(serverReqDecoder)
        
        // add NIO -> HTTP response encoder
        let serverResEncoder = HTTPServerResponseEncoder(
            serverHeader: self.configuration.serverName,
            dateCache: .eventLoop(channel.eventLoop)
        )
        handlers.append(serverResEncoder)
        
        // add server request -> response delegate
        let handler = HTTPServerHandler(
            responder: responder,
            errorHandler: self.configuration.errorHandler
        )
        handlers.append(handler)
        
        return handlers
    }
    
    private func http1Handlers(responder: Responder, channel: Channel) -> [ChannelHandler] {
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
        if self.configuration.supportPipelining {
            let pipelineHandler = HTTPServerPipelineHandler()
            handlers.append(pipelineHandler)
            otherHTTPHandlers.append(pipelineHandler)
        }
        
        // add response compressor if configured
        if self.configuration.supportCompression {
            let compressionHandler = HTTPResponseCompressor()
            handlers.append(compressionHandler)
            otherHTTPHandlers.append(compressionHandler)
        }
        
        // add NIO -> HTTP request decoder
        let serverReqDecoder = HTTPServerRequestDecoder(
            maxBodySize: self.configuration.maxBodySize
        )
        handlers.append(serverReqDecoder)
        otherHTTPHandlers.append(serverReqDecoder)
        
        // add NIO -> HTTP response encoder
        let serverResEncoder = HTTPServerResponseEncoder(
            serverHeader: self.configuration.serverName,
            dateCache: .eventLoop(channel.eventLoop)
        )
        handlers.append(serverResEncoder)
        otherHTTPHandlers.append(serverResEncoder)
        
        // add server request -> response delegate
        let handler = HTTPServerHandler(
            responder: responder,
            errorHandler: self.configuration.errorHandler
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
        return handlers
    }
    
    deinit {
        assert(!channel!.isActive, "HTTPServer deinitialized without calling shutdown()")
    }
}

final class HTTPServerErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Never
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("HTTP Server received error: \(error)")
        context.close(promise: nil)
    }
}
