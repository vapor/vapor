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

    var downstreamIsReady: Bool
    var readBuffer: [NIOAny]
    var hasReadPending: Bool
    var application: Application
    
    init(application: Application, maxBodySize: Int) {
        self.application = application
        self.maxBodySize = maxBodySize
        self.requestState = .ready
        self.logger = Logger(label: "codes.vapor.server")
        self.downstreamIsReady = true
        self.readBuffer = []
        self.hasReadPending = false
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        assert(context.channel.eventLoop.inEventLoop)
        guard self.downstreamIsReady else {
            self.readBuffer.append(data)
            return
        }
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
        case .body(var buffer):
            switch self.requestState {
            case .ready: assertionFailure("Unexpected state: \(self.requestState)")
            case .awaitingBody(let request):
                self.requestState = .awaitingEnd(request, buffer)
            case .awaitingEnd(let request, var previousBuffer):
                let stream = Request.BodyStream(on: context.eventLoop)
                request.bodyStorage = .stream(stream)
                context.fireChannelRead(self.wrapInboundOut(request))
                previousBuffer.writeBuffer(&buffer)
                let downstreamReady = stream.write(.buffer(previousBuffer))
                self.stopReading(until: downstreamReady, context: context)
                self.requestState = .streamingBody(stream)
            case .streamingBody(let stream):
                let downstreamReady = stream.write(.buffer(buffer))
                self.stopReading(until: downstreamReady, context: context)
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
                let downstreamReady = stream.write(.end)
                self.stopReading(until: downstreamReady, context: context)
            }
            self.requestState = .ready
        }
    }

    func read(context: ChannelHandlerContext) {
        if self.downstreamIsReady {
            context.read()
        } else {
            self.hasReadPending = true
        }
    }
    
    func channelReadComplete(context: ChannelHandlerContext) {
        context.fireChannelReadComplete()
    }

    func stopReading(until future: EventLoopFuture<Void>, context: ChannelHandlerContext) {
        assert(self.downstreamIsReady, "downstream not ready")
        self.downstreamIsReady = false
        future.whenComplete { result in
            self.downstreamIsReady = true
            var buffer = self.readBuffer
            self.readBuffer = []
            while let data = buffer.popLast() {
                self.channelRead(context: context, data: data)
            }
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
