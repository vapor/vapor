import NIO
import NIOHTTP1

final class HTTPClientProxyHandler: ChannelDuplexHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPClientResponsePart
    typealias OutboundIn = HTTPClientRequestPart
    typealias OutboundOut = HTTPClientRequestPart
    
    let hostname: String
    let port: Int
    var onConnect: (ChannelHandlerContext) -> ()
    
    private var buffer: [HTTPClientRequestPart]
    
    
    init(hostname: String, port: Int, onConnect: @escaping (ChannelHandlerContext) -> ()) {
        self.hostname = hostname
        self.port = port
        self.onConnect = onConnect
        self.buffer = []
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let res = self.unwrapInboundIn(data)
        switch res {
        case .head(let head):
            assert(head.status == .ok)
        case .end:
            self.configureTLS(context: context)
        default: assertionFailure("invalid state: \(res)")
        }
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let req = self.unwrapOutboundIn(data)
        self.buffer.append(req)
        promise?.succeed(())
    }
    
    func channelActive(context: ChannelHandlerContext) {
        self.sendConnect(context: context)
    }
    
    // MARK: Private
    
    private func configureTLS(context: ChannelHandlerContext) {
        self.onConnect(context)
        self.buffer.forEach { context.write(self.wrapOutboundOut($0), promise: nil) }
        context.flush()
        _ = context.pipeline.removeHandler(self)
    }
    
    private func sendConnect(context: ChannelHandlerContext) {
        var head = HTTPRequestHead(
            version: .init(major: 1, minor: 1),
            method: .CONNECT,
            uri: "\(self.hostname):\(self.port)"
        )
        head.headers.add(name: "proxy-connection", value: "keep-alive")
        context.write(self.wrapOutboundOut(.head(head)), promise: nil)
        context.write(self.wrapOutboundOut(.end(nil)), promise: nil)
        context.flush()
    }
}
