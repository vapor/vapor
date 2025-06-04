import NIOCore
import NIOHTTP1
import NIOWebSocket
import WebSocketKit
import HTTPTypes
import NIOHTTPTypes

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
    let httpHandlers: [any RemovableChannelHandler]

    init(
        httpRequestDecoder: ByteToMessageHandler<HTTPRequestDecoder>,
        httpHandlers: [any RemovableChannelHandler]
    ) {
        self.upgradeState = .ready
        self.httpRequestDecoder = httpRequestDecoder
        self.httpHandlers = httpHandlers
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let req = self.unwrapInboundIn(data)
        
        // check if request is upgrade
        let connectionHeaders = req.headers[values: .connection].map { $0.lowercased() }
        if connectionHeaders.contains("upgrade") {
            let buffer = UpgradeBufferHandler()
            do {
                _ = try context.channel.pipeline.syncOperations.addHandler(buffer, position: .before(self.httpRequestDecoder))
                self.upgradeState = .pending(req, buffer)
            } catch {
                self.errorCaught(context: context, error: error)
            }
        }
        
        context.fireChannelRead(data)
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let res = self.unwrapOutboundIn(data)
        
        struct SendableBox {
            let context: ChannelHandlerContext
            let buffer: UpgradeBufferHandler
            var handler: HTTPServerUpgradeHandler
            let protocolUpgrader: any HTTPServerProtocolUpgrader
        }
        
        // check upgrade
        switch self.upgradeState {
        case .pending(let req, let buffer):
            self.upgradeState = .upgraded
            let (status, upgrader) = res.responseBox.withLockedValue { box in
                return (box.status, box.upgrader)
            }
            if status == .switchingProtocols, let upgrader = upgrader {
                let protocolUpgrader = upgrader.applyUpgrade(req: req, res: res)
                let sendableBox = SendableBox(
                    context: context,
                    buffer: buffer,
                    handler: self,
                    protocolUpgrader: protocolUpgrader)
                let box = NIOLoopBound(sendableBox, eventLoop: context.eventLoop)

                let head = HTTPRequestHead(
                    version: req.version,
                    method: .init(req.method),
                    uri: req.url.string,
                    headers: .init(req.headers)
                )

                protocolUpgrader.buildUpgradeResponse(
                    channel: context.channel,
                    upgradeRequest: head,
                    initialResponseHeaders: [:]
                ).map { headers in
                    let sendableBox = box.value
                    res.headers = .init(headers, splitCookie: false)
                    sendableBox.context.write(sendableBox.handler.wrapOutboundOut(res), promise: promise)
                }.flatMap {
                    let sendableBox = box.value
                    let handlers: [any RemovableChannelHandler] = [sendableBox.handler] + sendableBox.handler.httpHandlers
                    return .andAllComplete(handlers.map { handler in
                        sendableBox.context.pipeline.syncOperations.removeHandler(handler)
                    }, on: box.value.context.eventLoop)
                }.flatMap {
                    let sendableBox = box.value
                    return sendableBox.protocolUpgrader.upgrade(context: sendableBox.context, upgradeRequest: head)
                }.flatMap {
                    let sendableBox = box.value
                    return sendableBox.context.pipeline.syncOperations.removeHandler(sendableBox.buffer)
                }.cascadeFailure(to: promise)
            } else {
                // reset handlers
                self.upgradeState = .ready
                context.channel.pipeline.syncOperations.removeHandler(buffer, promise: nil)
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
public protocol Upgrader: Sendable {
    func applyUpgrade(req: Request, res: Response) -> any HTTPServerProtocolUpgrader
}

/// Handles upgrading an HTTP connection to a WebSocket
public struct WebSocketUpgrader: Upgrader, Sendable {
    var maxFrameSize: WebSocketMaxFrameSize
    var shouldUpgrade: (@Sendable () -> EventLoopFuture<HTTPFields?>)
    var onUpgrade: @Sendable (WebSocket) -> ()
    
    public init(maxFrameSize: WebSocketMaxFrameSize, shouldUpgrade: @escaping (@Sendable () -> EventLoopFuture<HTTPFields?>), onUpgrade: @Sendable @escaping (WebSocket) -> ()) {
        self.maxFrameSize = maxFrameSize
        self.shouldUpgrade = shouldUpgrade
        self.onUpgrade = onUpgrade
    }
    
    public func applyUpgrade(req: Request, res: Response) -> any HTTPServerProtocolUpgrader {
        let webSocketUpgrader = NIOWebSocketServerUpgrader(maxFrameSize: self.maxFrameSize.value, automaticErrorHandling: false, shouldUpgrade: { _, _ in
            return self.shouldUpgrade().map { headers in
                if let headers {
                    return .init(headers)
                } else {
                    return nil
                }
            }
        }, upgradePipelineHandler: { channel, req in
            return WebSocket.server(on: channel, onUpgrade: self.onUpgrade)
        })
        
        return webSocketUpgrader
    }
}
