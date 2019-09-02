import NIO
import NIOHTTP1
import NIOWebSocket

internal final class WebSocketEchoServer {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let channel: Channel

    var port: Int {
        return Int(self.channel.localAddress!.port!)
    }

    init() {
        let upgrader = NIOWebSocketServerUpgrader(shouldUpgrade: { (channel: Channel, _: HTTPRequestHead) in channel.eventLoop.makeSucceededFuture(HTTPHeaders())
        }, upgradePipelineHandler: { (channel: Channel, _: HTTPRequestHead) in
            channel.pipeline.addHandler(WebSocketEchoServerWebSocketHandler())
        })

        self.channel = try! ServerBootstrap(group: self.group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                let httpHandler = WebSocketEchoServerHTTPHandler()
                let config: NIOHTTPServerUpgradeConfiguration = (
                    upgraders: [upgrader],
                    completionHandler: { _ in
                        channel.pipeline.removeHandler(httpHandler, promise: nil)
                    }
                )
                return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: config).flatMap {
                    channel.pipeline.addHandler(httpHandler)
                }
            }
            .bind(host: "127.0.0.1", port: 0).wait()
    }

    func shutdown() {
        try! self.group.syncShutdownGracefully()
    }
}

private final class WebSocketEchoServerHTTPHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    var resHead: HTTPResponseHead

    init() {
        self.resHead = .init(version: .init(major: 1, minor: 1), status: .ok, headers: .init([
            ("Connection", "close"),
            ("Content-Length", "0"),
        ]))
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let req = self.unwrapInboundIn(data)
        switch req {
        case .head(let head):
            guard head.method == .GET else {
                fatalError()
            }
        case .body:
            ()
        case .end:
            context.write(self.wrapOutboundOut(.head(self.resHead)), promise: nil)
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
        }
    }
}

private final class WebSocketEchoServerWebSocketHandler: ChannelInboundHandler {
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)

        switch frame.opcode {
        case .ping:
            var frameData = frame.data
            let maskingKey = frame.maskKey

            if let maskingKey = maskingKey {
                frameData.webSocketUnmask(maskingKey)
            }

            let responseFrame = WebSocketFrame(fin: true, opcode: .pong, data: frameData)
            context.writeAndFlush(self.wrapOutboundOut(responseFrame), promise: nil)
        default:
            fatalError()
        }
    }
}
