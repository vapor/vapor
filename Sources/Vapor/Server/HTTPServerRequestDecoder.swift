import NIO
import NIOHTTP1

final class HTTPServerRequestDecoder: ChannelDuplexHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = Request
    typealias OutboundIn = Never
    
    /// Tracks current HTTP server state
    enum RequestState {
        /// Waiting for request headers
        case ready
        case awaitingBody(Request)
        case awaitingEnd(Request, ByteBuffer)
        case streamingBody(Request.BodyStream)
    }
    
    /// Current HTTP state.
    var requestState: RequestState
    
    /// Maximum body size allowed per request.
    private let maxBodySize: Int
    
    private let logger: Logger

    var isWritable: Bool
    var hasReadPending: Bool
    
    init(maxBodySize: Int) {
        self.maxBodySize = maxBodySize
        self.requestState = .ready
        self.logger = Logger(label: "codes.vapor.server")
        self.isWritable = true
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
                    method: head.method,
                    urlString: head.uri,
                    version: head.version,
                    headersNoUpdate: head.headers,
                    on: context.channel
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
                let done = stream.write(.buffer(previousBuffer)).flatMap {
                    stream.write(.buffer(buffer))
                }
                self.updateReadability(done, context: context)
                self.requestState = .streamingBody(stream)
            case .streamingBody(let stream):
                self.isWritable = false
                let done = stream.write(.buffer(buffer))
                self.updateReadability(done, context: context)
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
                let done = stream.write(.end)
                self.updateReadability(done, context: context)
            }
            self.requestState = .ready
        }
    }

    func read(context: ChannelHandlerContext) {
        if self.isWritable {
            context.read()
        } else {
            self.hasReadPending = true
        }
    }

    func updateReadability(_ future: EventLoopFuture<Void>, context: ChannelHandlerContext) {
        self.isWritable = false
        future.whenComplete { result in
            self.isWritable = true
            if self.hasReadPending {
                self.hasReadPending = false
                context.read()
            }
            switch result {
            case .failure(let error):
                self.logger.error("Could not write body: \(error)")
            case .success: break
            }
        }
    }
}
