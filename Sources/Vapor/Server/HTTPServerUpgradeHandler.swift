import NIO
import NIOHTTP1

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
    let otherHTTPHandlers: [RemovableChannelHandler]
    
    init(
        httpRequestDecoder: ByteToMessageHandler<HTTPRequestDecoder>,
        otherHTTPHandlers: [RemovableChannelHandler]
    ) {
        self.upgradeState = .ready
        self.httpRequestDecoder = httpRequestDecoder
        self.otherHTTPHandlers = otherHTTPHandlers
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let req = self.unwrapInboundIn(data)
        
        // check if request is upgrade
        let connectionHeaders = Set(req.headers[canonicalForm: "connection"].map { $0.lowercased() })
        if connectionHeaders.contains("upgrade") {
            // remove http decoder
            let buffer = UpgradeBufferHandler()
            _ = context.channel.pipeline.addHandler(buffer, position: .after(self.httpRequestDecoder)).flatMap {
                return context.channel.pipeline.removeHandler(self.httpRequestDecoder)
            }
            self.upgradeState = .pending(req, buffer)
        }
        
        context.fireChannelRead(data)
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let res = self.unwrapOutboundIn(data)
        
        context.write(self.wrapOutboundOut(res), promise: promise)
        
        // check upgrade
        switch self.upgradeState {
        case .pending(let req, let buffer):
            if res.status == .switchingProtocols, let upgrader = res.upgrader {
                // do upgrade
                let handlers: [RemovableChannelHandler] = [self] + self.otherHTTPHandlers
                _ = EventLoopFuture<Void>.andAllComplete(handlers.map { handler in
                    return context.pipeline.removeHandler(handler)
                }, on: context.eventLoop).flatMap { _ in
                    return upgrader.upgrade(
                        context: context,
                        upgradeRequest: .init(
                            version: req.version,
                            method: req.method,
                            uri: req.urlString
                        )
                    )
                    }.flatMap {
                        return context.pipeline.removeHandler(buffer)
                }
                self.upgradeState = .upgraded
            } else {
                // reset handlers
                self.upgradeState = .ready
                _ = context.channel.pipeline.addHandler(self.httpRequestDecoder, position: .after(buffer)).flatMap {
                    return context.channel.pipeline.removeHandler(buffer)
                }
            }
        case .ready: break
        case .upgraded: break
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
