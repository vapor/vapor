import Instrumentation
import NIO

final class HTTPServerHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = Request
    typealias OutboundOut = Response
    
    let responder: Responder
    let logger: Logger
    var isShuttingDown: Bool
    
    init(responder: Responder, logger: Logger) {
        self.responder = responder
        self.logger = logger
        self.isShuttingDown = false
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let request = self.unwrapInboundIn(data)
        InstrumentationSystem.instrument.extract(request.headers, into: &request.baggage, using: HTTPHeadersExtractor())
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
            let keepAlive = !self.isShuttingDown && request.isKeepAlive
            if self.isShuttingDown {
                self.logger.debug("In-flight request has completed")
            }
            response.headers.add(name: .connection, value: keepAlive ? "keep-alive" : "close")
            let done = context.write(self.wrapOutboundOut(response))
            done.whenComplete { result in
                switch result {
                case .success:
                    if !keepAlive {
                        context.close(mode: .output, promise: nil)
                    }
                case .failure(let error):
                    self.errorCaught(context: context, error: error)
                }
            }
        }
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case is ChannelShouldQuiesceEvent:
            self.logger.trace("HTTP handler will no longer respect keep-alive")
            self.isShuttingDown = true
        default:
            self.logger.trace("Unhandled user event: \(event)")
        }
    }
}

private struct HTTPHeadersExtractor: Extractor {
    func extract(key: String, from headers: HTTPHeaders) -> String? {
        headers.first(name: key)
    }
}
