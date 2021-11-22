import NIO
import NIOHTTP1

fileprivate struct ResponseEndSentEvent {
    
}

final class HTTPServerRequestHandler: ChannelDuplexHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = Request
    typealias OutboundIn = Response
    typealias OutboundOut = HTTPServerResponsePart

    private enum RequestState {
        case ready
        case awaitingBody(Request)
        case awaitingEnd(Request, ByteBuffer)
        case streamingBody(Request.BodyStream)
        case skipping
    }

    /// Optional server header.
    private let serverHeader: String?
    private let dateCache: RFC1123DateCache

    private var requestState: RequestState
    private var bodyStreamState: HTTPBodyStreamState

    private var logger: Logger {
        self.application.logger
    }
    private var application: Application

    init(application: Application, serverHeader: String?, dateCache: RFC1123DateCache) {
        self.application = application
        self.requestState = .ready
        self.bodyStreamState = .init()

        self.serverHeader = serverHeader
        self.dateCache = dateCache
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
            case .ready, .awaitingEnd:
                assertionFailure("Unexpected state: \(self.requestState)")
            case .awaitingBody(let request):
                if request.headers.first(name: .contentLength) == buffer.readableBytes.description {
                    self.requestState = .awaitingEnd(request, buffer)
                } else {
                    let stream = Request.BodyStream(on: context.eventLoop)
                    request.bodyStorage = .stream(stream)
                    self.requestState = .streamingBody(stream)
                    context.fireChannelRead(self.wrapInboundOut(request))
                    self.handleBodyStreamStateResult(
                        context: context,
                        self.bodyStreamState.didReadBytes(buffer),
                        stream: stream
                    )
                }
            case .streamingBody(let stream):
                self.handleBodyStreamStateResult(
                    context: context,
                    self.bodyStreamState.didReadBytes(buffer),
                    stream: stream
                )
            case .skipping: break
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
                self.handleBodyStreamStateResult(
                    context: context,
                    self.bodyStreamState.didEnd(),
                    stream: stream
                )
            case .skipping: break
            }
            self.requestState = .ready
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        switch self.requestState {
        case .streamingBody(let stream):
            self.handleBodyStreamStateResult(
                context: context,
                self.bodyStreamState.didError(error),
                stream: stream
            )
        default:
            break
        }
        context.fireErrorCaught(error)
    }

    func channelInactive(context: ChannelHandlerContext) {
        switch self.requestState {
        case .streamingBody(let stream):
            self.handleBodyStreamStateResult(
                context: context,
                self.bodyStreamState.didEnd(),
                stream: stream
            )
        default:
            break
        }
        context.fireChannelInactive()
    }

    private func handleBodyStreamStateResult(
        context: ChannelHandlerContext,
        _ result: HTTPBodyStreamState.Result,
        stream: Request.BodyStream
    ) {
        switch result.action {
        case .nothing: break
        case .write(let buffer):
            stream.write(.buffer(buffer)).whenComplete { writeResult in
                switch writeResult {
                case .failure(let error):
                    self.handleBodyStreamStateResult(
                        context: context,
                        self.bodyStreamState.didError(error),
                        stream: stream
                    )
                case .success: break
                }
                self.handleBodyStreamStateResult(
                    context: context,
                    self.bodyStreamState.didWrite(),
                    stream: stream
                )
            }
        case .close(let maybeError):
            if let error = maybeError {
                stream.write(.error(error), promise: nil)
            } else {
                stream.write(.end, promise: nil)
            }
        }
        if result.callRead {
            context.read()
        }
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case is ResponseEndSentEvent:
            switch self.requestState {
            case .streamingBody(let bodyStream):
                // Response ended during request stream.
                if !bodyStream.isBeingRead {
                    self.logger.trace("Response already sent, draining unhandled request stream.")
                    bodyStream.read { _, promise in
                        promise?.succeed(())
                    }
                }
            case .awaitingBody, .awaitingEnd:
                // Response ended before request started streaming.
                self.logger.trace("Response already sent, skipping request body.")
                self.requestState = .skipping
            case .ready, .skipping:
                // Response ended after request had been read.
                break
            }
        case is ChannelShouldQuiesceEvent:
            switch self.requestState {
            case .ready:
                self.logger.trace("Closing keep-alive HTTP connection since server is going away")
                context.channel.close(mode: .all, promise: nil)
            default:
                self.logger.debug("A request is currently in-flight")
                context.fireUserInboundEventTriggered(event)
            }
        default:
            self.logger.trace("Unhandled user event: \(event)")
        }
    }
}

extension HTTPServerRequestHandler {
    func read(context: ChannelHandlerContext) {
        switch self.requestState {
        case .streamingBody(let stream):
            self.handleBodyStreamStateResult(
                context: context,
                self.bodyStreamState.didReceiveReadRequest(),
                stream: stream
            )
        default:
            context.read()
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let response = self.unwrapOutboundIn(data)
        // add a RFC1123 timestamp to the Date header to make this
        // a valid request
        response.headers.add(name: "date", value: self.dateCache.currentTimestamp())
        
        if let server = self.serverHeader {
            response.headers.add(name: "server", value: server)
        }
        
        // begin serializing
        context.write(wrapOutboundOut(.head(.init(
            version: response.version,
            status: response.status,
            headers: response.headers
        ))), promise: nil)

        
        if response.status == .noContent || response.forHeadRequest {
            // don't send bodies for 204 (no content) responses
            // or HEAD requests
            context.fireUserInboundEventTriggered(ResponseEndSentEvent())
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: promise)
        } else {
            switch response.body.storage {
            case .none:
                context.fireUserInboundEventTriggered(ResponseEndSentEvent())
                context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)
            case .buffer(let buffer):
                self.writeAndflush(buffer: buffer, context: context, promise: promise)
            case .string(let string):
                var buffer = context.channel.allocator.buffer(capacity: string.count)
                buffer.writeString(string)
                self.writeAndflush(buffer: buffer, context: context, promise: promise)
            case .staticString(let string):
                var buffer = context.channel.allocator.buffer(capacity: string.utf8CodeUnitCount)
                buffer.writeStaticString(string)
                self.writeAndflush(buffer: buffer, context: context, promise: promise)
            case .data(let data):
                var buffer = context.channel.allocator.buffer(capacity: data.count)
                buffer.writeBytes(data)
                self.writeAndflush(buffer: buffer, context: context, promise: promise)
            case .dispatchData(let data):
                var buffer = context.channel.allocator.buffer(capacity: data.count)
                buffer.writeDispatchData(data)
                self.writeAndflush(buffer: buffer, context: context, promise: promise)
            case .stream(let stream):
                let channelStream = ChannelResponseBodyStream(
                    context: context,
                    handler: self,
                    promise: promise,
                    count: stream.count == -1 ? nil : stream.count
                )
                stream.callback(channelStream)
            }
        }
    }
    
    /// Writes a `ByteBuffer` to the context.
    private func writeAndflush(buffer: ByteBuffer, context: ChannelHandlerContext, promise: EventLoopPromise<Void>?) {
        if buffer.readableBytes > 0 {
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        context.fireUserInboundEventTriggered(ResponseEndSentEvent())
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)
    }
}

extension HTTPPart: CustomStringConvertible {
    public var description: String {
        switch self {
        case .head(let head):
            return "head: \(head)"
        case .body(let body):
            return "body: \(body)"
        case .end(let headers):
            if let headers = headers {
                return "end: \(headers)"
            } else {
                return "end"
            }
        }
    }
}

struct HTTPBodyStreamState: CustomStringConvertible {
    struct Result {
        enum Action {
            case nothing
            case write(ByteBuffer)
            case close(Error?)
        }
        let action: Action
        let callRead: Bool
    }

    private struct BufferState {
        var bufferedWrites: CircularBuffer<ByteBuffer>
        var heldUpRead: Bool
        var hasClosed: Bool

        mutating func append(_ buffer: ByteBuffer) {
            self.bufferedWrites.append(buffer)
        }

        var isEmpty: Bool {
            return self.bufferedWrites.isEmpty
        }

        mutating func removeFirst() -> ByteBuffer {
            return self.bufferedWrites.removeFirst()
        }
    }

    private enum State {
        case idle
        case writing(BufferState)
        case error(Error)
    }

    private var state: State

    var description: String {
        "\(self.state)"
    }

    init() {
        self.state = .idle
    }

    mutating func didReadBytes(_ buffer: ByteBuffer) -> Result {
        switch self.state {
        case .idle:
            self.state = .writing(.init(
                bufferedWrites: .init(initialCapacity: 4),
                heldUpRead: false,
                hasClosed: false
            ))
            return .init(action: .write(buffer), callRead: false)
        case .writing(var buffers):
            buffers.append(buffer)
            self.state = .writing(buffers)
            return .init(action: .nothing, callRead: false)
        case .error:
            return .init(action: .nothing, callRead: false)
        }
    }

    mutating func didReceiveReadRequest() -> Result {
        switch self.state {
        case .idle:
            return .init(action: .nothing, callRead: true)
        case .writing(var buffers):
            buffers.heldUpRead = true
            self.state = .writing(buffers)
            return .init(action: .nothing, callRead: false)
        case .error:
            return .init(action: .nothing, callRead: false)
        }
    }

    mutating func didEnd() -> Result {
        switch self.state {
        case .idle:
            return .init(action: .close(nil), callRead: false)
        case .writing(var buffers):
            buffers.hasClosed = true
            self.state = .writing(buffers)
            return .init(action: .nothing, callRead: false)
        case .error:
            return .init(action: .nothing, callRead: false)
        }
    }

    mutating func didError(_ error: Error) -> Result {
        switch self.state {
        case .idle:
            self.state = .error(error)
            return .init(action: .close(error), callRead: false)
        case .writing:
            self.state = .error(error)
            return .init(action: .nothing, callRead: false)
        case .error:
            return .init(action: .nothing, callRead: false)
        }
    }

    mutating func didWrite() -> Result {
        switch self.state {
        case .idle:
            self.illegalTransition()
        case .writing(var buffers):
            if buffers.isEmpty {
                self.state = .idle
                return .init(
                    action: buffers.hasClosed ? .close(nil) : .nothing,
                    callRead: buffers.heldUpRead
                )
            } else {
                let first = buffers.removeFirst()
                self.state = .writing(buffers)
                return .init(action: .write(first), callRead: false)
            }
        case .error(let error):
            return .init(action: .close(error), callRead: false)
        }
    }

    private func illegalTransition(_ function: String = #function) -> Never {
        preconditionFailure("illegal transition \(function) in \(self)")
    }
}

private final class ChannelResponseBodyStream: BodyStreamWriter {
    let context: ChannelHandlerContext
    let handler: HTTPServerRequestHandler
    let promise: EventLoopPromise<Void>?
    let count: Int?
    var currentCount: Int
    var isComplete: Bool

    var eventLoop: EventLoop {
        return self.context.eventLoop
    }

    enum Error: Swift.Error {
        case tooManyBytes
        case notEnoughBytes
    }

    init(
        context: ChannelHandlerContext,
        handler: HTTPServerRequestHandler,
        promise: EventLoopPromise<Void>?,
        count: Int?
    ) {
        self.context = context
        self.handler = handler
        self.promise = promise
        self.count = count
        self.currentCount = 0
        self.isComplete = false
    }
    
    func write(_ result: BodyStreamResult, promise: EventLoopPromise<Void>?) {
        switch result {
        case .buffer(let buffer):
            self.context.writeAndFlush(self.handler.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: promise)
            self.currentCount += buffer.readableBytes
            if let count = self.count, self.currentCount > count {
                self.promise?.fail(Error.tooManyBytes)
                promise?.fail(Error.notEnoughBytes)
            }
        case .end:
            self.isComplete = true
            if let count = self.count, self.currentCount != count {
                self.promise?.fail(Error.notEnoughBytes)
                promise?.fail(Error.notEnoughBytes)
            }
            self.context.fireUserInboundEventTriggered(ResponseEndSentEvent())
            self.context.writeAndFlush(self.handler.wrapOutboundOut(.end(nil)), promise: promise)
            self.promise?.succeed(())
        case .error(let error):
            self.isComplete = true
            self.context.fireUserInboundEventTriggered(ResponseEndSentEvent())
            self.context.writeAndFlush(self.handler.wrapOutboundOut(.end(nil)), promise: promise)
            self.promise?.fail(error)
        }
    }

    deinit {
        assert(self.isComplete, "Response body stream writer deinitialized before .end or .error was sent.")
    }
}

