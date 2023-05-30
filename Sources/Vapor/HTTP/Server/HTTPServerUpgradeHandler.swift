import NIOCore
import NIOHTTP1
import NIOWebSocket
import WebSocketKit
import NIOConcurrencyHelpers

final class HTTPServerUpgradeHandler: ChannelDuplexHandler, RemovableChannelHandler {
    typealias InboundIn = Request
    typealias OutboundIn = Response
    typealias OutboundOut = Response
    
    
    private enum UpgradeState: Sendable {
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
        let contextBox = NIOLoopBound(context, eventLoop: context.eventLoop)
        let sendableBox = NIOLoopBound(self, eventLoop: context.eventLoop)
        
        // check upgrade
        switch self.upgradeState {
        case .pending(let req, let buffer):
            self.upgradeState = .upgraded
            if res.status == .switchingProtocols, let upgrader = res.upgrader {
                let protocolUpgrader = NIOLoopBound(upgrader.applyUpgrade(req: req, res: res), eventLoop: context.eventLoop)

                let head = HTTPRequestHead(
                    version: req.version,
                    method: req.method,
                    uri: req.url.string,
                    headers: req.headers
                )

                protocolUpgrader.value.buildUpgradeResponse(
                    channel: context.channel,
                    upgradeRequest: head,
                    initialResponseHeaders: [:]
                ).map { headers in
                    res.headers = headers
                    contextBox.value.write(sendableBox.value.wrapOutboundOut(res), promise: promise)
                }.flatMap {
                    let handlers: [RemovableChannelHandler] = [sendableBox.value] + sendableBox.value.httpHandlers
                    return .andAllComplete(handlers.map { handler in
                        return contextBox.value.pipeline.removeHandler(handler)
                    }, on: contextBox.value.eventLoop)
                }.flatMap {
                    return protocolUpgrader.value.upgrade(context: contextBox.value, upgradeRequest: head)
                }.flatMap {
                    return contextBox.value.pipeline.removeHandler(buffer)
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

private final class UpgradeBufferHandler: ChannelInboundHandler, RemovableChannelHandler, Sendable {
    typealias InboundIn = ByteBuffer
    
    private let buffer: NIOLockedValueBox<[ByteBuffer]>
    
    init() {
        self.buffer = .init([])
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = self.unwrapInboundIn(data)
        self.buffer.withLockedValue {
            $0.append(data)
        }
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        self.buffer.withLockedValue {
            for data in $0 {
                context.fireChannelRead(NIOAny(data))
            }
        }
    }
}

/// Conformance for any struct that performs an HTTP Upgrade
public protocol Upgrader: Sendable {
    func applyUpgrade(req: Request, res: Response) -> HTTPServerProtocolUpgrader
}

/// Handles upgrading an HTTP connection to a WebSocket
public struct WebSocketUpgrader: Upgrader, Sendable {
    var maxFrameSize: WebSocketMaxFrameSize
    var shouldUpgrade: (@Sendable () -> EventLoopFuture<HTTPHeaders?>)
    var onUpgrade: @Sendable (WebSocket) -> ()
    
    public init(maxFrameSize: WebSocketMaxFrameSize, shouldUpgrade: @escaping (@Sendable () -> EventLoopFuture<HTTPHeaders?>), onUpgrade: @Sendable @escaping (WebSocket) -> ()) {
        self.maxFrameSize = maxFrameSize
        self.shouldUpgrade = shouldUpgrade
        self.onUpgrade = onUpgrade
    }
    
    public func applyUpgrade(req: Request, res: Response) -> HTTPServerProtocolUpgrader {
        let webSocketUpgrader = NIOWebSocketServerUpgrader(maxFrameSize: self.maxFrameSize.value, automaticErrorHandling: false, shouldUpgrade: { _, _ in
            return self.shouldUpgrade()
        }, upgradePipelineHandler: { channel, req in
            return WebSocket.server(on: channel, onUpgrade: self.onUpgrade)
        })
        
        return webSocketUpgrader
    }
}
