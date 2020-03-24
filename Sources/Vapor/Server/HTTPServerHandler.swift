import NIO

final class HTTPServerHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = Request
    typealias OutboundOut = Response
    
    let responder: Responder
    
    init(responder: Responder) {
        self.responder = responder
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let request = self.unwrapInboundIn(data)
        
        // query delegate for response
        self.responder.respond(to: request).whenComplete { response in
            switch response {
            case .failure(let error):
                self.errorCaught(context: context, error: error)
            case .success(let response):
                let contentLength = response.headers.first(name: .contentLength)
                if request.method == .HEAD {
                    response.body = .init()
                }
                response.headers.replaceOrAdd(name: .contentLength, value: contentLength ?? "0")
                self.serialize(response, for: request, context: context)
            }
        }
    }
    
    func serialize(_ response: Response, for request: Request, context: ChannelHandlerContext) {
        switch request.version.major {
        case 2:
            context.write(self.wrapOutboundOut(response), promise: nil)
        default:
            response.headers.add(name: .connection, value: request.isKeepAlive ? "keep-alive" : "close")
            let done = context.write(self.wrapOutboundOut(response))
            if !request.isKeepAlive {
                done.whenComplete { _ in
                    context.close(mode: .output, promise: nil)
                }
            }
        }
    }
}
