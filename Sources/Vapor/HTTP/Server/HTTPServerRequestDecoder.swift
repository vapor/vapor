import NIO
import NIOHTTP1

final class HTTPServerRequestDecoder: ChannelDuplexHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = Request
    typealias OutboundIn = Never

    enum RequestState {
        case ready
        case awaitingBody(Request)
        case awaitingEnd(Request, ByteBuffer)
        case streamingBody(Request.BodyStream)
    }

    var requestState: RequestState
    private let logger: Logger
    var pendingWriteCount: Int
    var hasReadPending: Bool
    var application: Application
    
    init(application: Application) {
        self.application = application
        self.requestState = .ready
        self.logger = Logger(label: "codes.vapor.server")
        self.pendingWriteCount = 0
        self.hasReadPending = false
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        assert(context.channel.eventLoop.inEventLoop)
        let part = self.unwrapInboundIn(data)
        self.logger.trace("Decoded HTTP part: \(part)")
        switch part {
        case .head(let head):
            switch self.requestState {
            case .ready:
                let request = Request(
                    application: self.application,
                    method: head.method,
                    url: .init(string: head.uri),
                    version: head.version,
                    headersNoUpdate: head.headers,
                    remoteAddress: context.channel.remoteAddress,
                    logger: self.application.logger,
                    on: context.channel.eventLoop
                )
                switch head.version.major {
                case 2:
                    request.isKeepAlive = true
                default:
                    request.isKeepAlive = head.isKeepAlive
                }
                self.requestState = .awaitingBody(request)
            default: assertionFailure("Unexpected state: \(self.requestState)")
            }
        case .body(let buffer):
            switch self.requestState {
            case .ready: assertionFailure("Unexpected state: \(self.requestState)")
            case .awaitingBody(let request):
                self.requestState = .awaitingEnd(request, buffer)
            case .awaitingEnd(let request, let previousBuffer):
                let stream = Request.BodyStream(on: context.eventLoop)
                request.bodyStorage = .stream(stream)
                context.fireChannelRead(self.wrapInboundOut(request))
                self.write(.buffer(previousBuffer), to: stream, context: context)
                self.write(.buffer(buffer), to: stream, context: context)
                self.requestState = .streamingBody(stream)
            case .streamingBody(let stream):
                self.write(.buffer(buffer), to: stream, context: context)
            }
        case .end(let tailHeaders):
            assert(tailHeaders == nil, "Tail headers are not supported.")
            switch self.requestState {
            case .ready: assertionFailure("Unexpected state: \(self.requestState)")
            case .awaitingBody(let request):
                context.fireChannelRead(self.wrapInboundOut(request))
            case .awaitingEnd(let request, let buffer):
                request.bodyStorage = .collected(buffer)
                context.fireChannelRead(self.wrapInboundOut(request))
            case .streamingBody(let stream):
                self.write(.end, to: stream, context: context)
            }
            self.requestState = .ready
        }
    }

    func read(context: ChannelHandlerContext) {
        if self.pendingWriteCount <= 0 {
            context.read()
        } else {
            self.hasReadPending = true
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        switch self.requestState {
        case .streamingBody(let stream):
            stream.write(.error(error), promise: nil)
        default:
            break
        }
        context.fireErrorCaught(error)
    }

    func write(_ part: BodyStreamResult, to stream: Request.BodyStream, context: ChannelHandlerContext) {
        self.pendingWriteCount += 1
        stream.write(part).whenComplete { result in
            self.pendingWriteCount -= 1
            if self.hasReadPending {
                self.hasReadPending = false
                self.read(context: context)
            }
            switch result {
            case .failure(let error):
                self.logger.error("Could not write body: \(error)")
            case .success: break
            }
        }
    }
}
