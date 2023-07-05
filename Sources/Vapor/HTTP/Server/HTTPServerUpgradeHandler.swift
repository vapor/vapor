import NIOCore
import NIOHTTP1
import NIOWebSocket
import WebSocketKit

final class HTTPServerUpgradeHandler: ChannelDuplexHandler, RemovableChannelHandler {
    typealias InboundIn = Request
    typealias OutboundIn = Response
    typealias OutboundOut = Response
    
    
    private enum UpgradeState {
        case ready
        case pending(Request, UpgradeBufferHandler)
        case upgraded
    }
    
    
    private var upgradeState: UpgradeState
    let httpRequestDecoder: ByteToMessageHandler<HTTPRequestDecoder>
    let httpHandlers: [RemovableChannelHandler]
    
    init(
        httpRequestDecoder: ByteToMessageHandler<HTTPRequestDecoder>,
        httpHandlers: [RemovableChannelHandler]
    ) {
        self.upgradeState = .ready
        self.httpRequestDecoder = httpRequestDecoder
        self.httpHandlers = httpHandlers
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let req = self.unwrapInboundIn(data)
        
        // check if request is upgrade
        let connectionHeaders = Set(req.headers[canonicalForm: "connection"].map { $0.lowercased() })
        if connectionHeaders.contains("upgrade") {
            let buffer = UpgradeBufferHandler()
            _ = context.channel.pipeline.addHandler(buffer, position: .before(self.httpRequestDecoder))
            self.upgradeState = .pending(req, buffer)
        }
        
        context.fireChannelRead(data)
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let res = self.unwrapOutboundIn(data)
        
        // check upgrade
        switch self.upgradeState {
        case .pending(let req, let buffer):
            self.upgradeState = .upgraded
            if res.status == .switchingProtocols, let upgrader = res.upgrader {
                let protocolUpgrader = upgrader.applyUpgrade(req: req, res: res)

                var head = HTTPRequestHead(
                    version: req.version,
                    method: req.method,
                    uri: req.url.string
                )
                head.headers = req.headers

                protocolUpgrader.buildUpgradeResponse(
                    channel: context.channel,
                    upgradeRequest: head,
                    initialResponseHeaders: [:]
                ).map { headers in
                    res.headers = headers
                    context.write(self.wrapOutboundOut(res), promise: promise)
                }.flatMap {
                    let handlers: [RemovableChannelHandler] = [self] + self.httpHandlers
                    return .andAllComplete(handlers.map { handler in
                        return context.pipeline.removeHandler(handler)
                    }, on: context.eventLoop)
                }.flatMap {
                    return protocolUpgrader.upgrade(context: context, upgradeRequest: head)
                }.flatMap {
                    return context.pipeline.removeHandler(buffer)
                }.cascadeFailure(to: promise)
            } else {
                // reset handlers
                self.upgradeState = .ready
                context.channel.pipeline.removeHandler(buffer, promise: nil)
                context.write(self.wrapOutboundOut(res), promise: promise)
            }
        case .ready, .upgraded:
            context.write(self.wrapOutboundOut(res), promise: promise)
        }
    }
}

private final class UpgradeBufferHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = ByteBuffer
    
    var buffer: [ByteBuffer]
    
    init() {
        self.buffer = []
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = self.unwrapInboundIn(data)
        self.buffer.append(data)
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        for data in self.buffer {
            context.fireChannelRead(NIOAny(data))
        }
    }
}

/// Conformance for any struct that performs an HTTP Upgrade
public protocol Upgrader {
    func applyUpgrade(req: Request, res: Response) -> HTTPServerProtocolUpgrader
}

/// Handles upgrading an HTTP connection to a WebSocket
public struct WebSocketUpgrader: Upgrader {
    
    var maxFrameSize: WebSocketMaxFrameSize
    var shouldUpgrade: (() -> EventLoopFuture<HTTPHeaders?>)
    var onUpgrade: (WebSocket) -> ()
    
    // can maybe mirror config in headers since it comes from them
    // so the api wont need to change?
    // really feels like the upgrader shoold know about the pmce so calers dont need to init headers
    // and pmce
    //
    
    public init(maxFrameSize: WebSocketMaxFrameSize, shouldUpgrade: @escaping (() -> EventLoopFuture<HTTPHeaders?>), onUpgrade: @escaping (WebSocket) -> ()) {
        self.maxFrameSize = maxFrameSize
        self.shouldUpgrade = shouldUpgrade
        self.onUpgrade = onUpgrade
    }
    
    public func applyUpgrade(req: Request, res: Response) -> HTTPServerProtocolUpgrader {
        let webSocketUpgrader = NIOWebSocketServerUpgrader(maxFrameSize: self.maxFrameSize.value, automaticErrorHandling: false, shouldUpgrade: { _, _ in
            return self.shouldUpgrade()
        }, upgradePipelineHandler: { channel, req  in
            
            var wsConfig = WebSocket.Configuration()
                      
            if let config = PMCE.DeflateConfig.configsFrom(headers: req.headers).first {
                print("deflate config applied \(config)")
                print("from \(req.headers)")
                
                wsConfig.deflateConfig = config
            }else {
                print("NO PMCE config in headers...")
            }
            
            return WebSocket.server(on: channel,
                                    config: wsConfig,
                                    onUpgrade: self.onUpgrade)
        })
        
        return webSocketUpgrader
    }
}
