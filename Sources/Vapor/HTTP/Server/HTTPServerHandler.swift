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
        self.responder.respond(to: request).whenComplete { response in
            self.serialize(response, for: request, context: context)
        }
    }

    func serialize(_ response: Result<Response, Error>, for request: Request, context: ChannelHandlerContext) {
        switch response {
        case .failure(let error):
            self.errorCaught(context: context, error: error)
        case .success(let response):
            if request.method == .HEAD {
                response.forHeadRequest = true
            }
            self.serialize(response, for: request, context: context)
        }
    }
    
    func serialize(_ response: Response, for request: Request, context: ChannelHandlerContext) {
        switch request.version.major {
        case 2:
            context.write(self.wrapOutboundOut(response), promise: nil)
        default:
            response.headers.add(name: .connection, value: request.isKeepAlive ? "keep-alive" : "close")
            let done = context.write(self.wrapOutboundOut(response))
            done.whenComplete { result in
                switch result {
                case .success:
                    if !request.isKeepAlive {
                        context.close(mode: .output, promise: nil)
                    }
                case .failure(let error):
                    self.errorCaught(context: context, error: error)
                }
            }
        }
    }
}
