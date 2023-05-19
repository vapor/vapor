import NIOCore
import Logging
import NIOConcurrencyHelpers

final class HTTPServerHandler: ChannelInboundHandler, RemovableChannelHandler, Sendable {
    typealias InboundIn = Request
    typealias OutboundOut = Response
    
    let responder: Responder
    let logger: Logger
    let isShuttingDown: NIOLockedValueBox<Bool>
    
    init(responder: Responder, logger: Logger) {
        self.responder = responder
        self.logger = logger
        self.isShuttingDown = .init(false)
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let contextBox = NIOLoopBound(context, eventLoop: context.eventLoop)
        let request = self.unwrapInboundIn(data)
        self.responder.respond(to: request).whenComplete { response in
            self.serialize(response, for: request, context: contextBox.value)
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
        let contextBox = NIOLoopBound(context, eventLoop: context.eventLoop)
        switch request.version.major {
        case 2:
            context.write(self.wrapOutboundOut(response), promise: nil)
        default:
            let keepAlive = !self.isShuttingDown.withLockedValue({ $0 }) && request.isKeepAlive.withLockedValue { $0 }
            if self.isShuttingDown.withLockedValue({ $0 }) {
                self.logger.debug("In-flight request has completed")
            }
            response.headers.add(name: .connection, value: keepAlive ? "keep-alive" : "close")
            let done = context.write(self.wrapOutboundOut(response))
            done.whenComplete { result in
                switch result {
                case .success:
                    if !keepAlive {
                        contextBox.value.close(mode: .output, promise: nil)
                    }
                case .failure(let error):
                    if case .stream(let stream) = response.body.storage {
                        stream.callback(ErrorBodyStreamWriter(eventLoop: request.eventLoop, error: error))
                    }
                    self.errorCaught(context: contextBox.value, error: error)
                }
            }
        }
    }
    
    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case is ChannelShouldQuiesceEvent:
            self.logger.trace("HTTP handler will no longer respect keep-alive")
            self.isShuttingDown.withLockedValue { $0 = true }
        default:
            self.logger.trace("Unhandled user event: \(event)")
        }
    }
}

struct ErrorBodyStreamWriter: Sendable, BodyStreamWriter {
    var eventLoop: EventLoop
    var error: Error
    func write(_ result: BodyStreamResult, promise: EventLoopPromise<Void>?) {
        promise?.fail(error)
    }
}
