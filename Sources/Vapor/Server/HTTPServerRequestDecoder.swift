import NIO
import NIOHTTP1

final class HTTPServerRequestDecoder: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = Request
    
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
    
    init(maxBodySize: Int) {
        self.maxBodySize = maxBodySize
        self.requestState = .ready
        self.logger = Logger(label: "http-kit.server-decoder")
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        assert(context.channel.eventLoop.inEventLoop)
        let part = self.unwrapInboundIn(data)
        self.logger.debug("got \(part)")
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
                let stream = Request.BodyStream()
                request.bodyStorage = .stream(stream)
                context.fireChannelRead(self.wrapInboundOut(request))
                stream.write(.buffer(previousBuffer))
                stream.write(.buffer(buffer))
                self.requestState = .streamingBody(stream)
            case .streamingBody(let stream):
                stream.write(.buffer(buffer))
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
                stream.write(.end)
            }
            self.requestState = .ready
        }
    }
}
