import NIO
import NIOHTTP1
import NIOWebSocket

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
                switch upgrader {
                case .webSocket(let maxFrameSize, let onUpgrade):
                    let webSocketUpgrader = NIOWebSocketServerUpgrader(maxFrameSize: maxFrameSize.value, automaticErrorHandling: false, shouldUpgrade: { channel, _ in
                        return channel.eventLoop.makeSucceededFuture([:])
                    }, upgradePipelineHandler: { channel, req in
                        return WebSocket.server(on: channel, onUpgrade: onUpgrade)
                    })

                    var head = HTTPRequestHead(
                        version: req.version,
                        method: req.method,
                        uri: req.url.string
                    )
                    head.headers = req.headers

                    webSocketUpgrader.buildUpgradeResponse(
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
                        return webSocketUpgrader.upgrade(context: context, upgradeRequest: head)
                    }.flatMap {
                        return context.pipeline.removeHandler(buffer)
                    }.cascadeFailure(to: promise)
                }
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
