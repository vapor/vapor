import Logging
import NIOCore
import NIOHTTP1
import Foundation

final class HTTPServerRequestDecoder: ChannelDuplexHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = Request
    typealias OutboundIn = Never

    enum RequestState {
        case ready
        case awaitingBody(Request)
        case awaitingEnd(Request, ByteBuffer)
        case streamingBody(Request.BodyStream)
        case skipping
    }

    var requestState: RequestState
    var bodyStreamState: HTTPBodyStreamState

    var logger: Logger {
        self.application.logger
    }
    var application: Application
    
    init(application: Application) {
        self.application = application
        self.requestState = .ready
        self.bodyStreamState = .init()
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        assert(context.channel.eventLoop.inEventLoop)
        let part = self.unwrapInboundIn(data)
        self.logger.trace("Decoded HTTP part: \(part)")
        switch part {
        case .head(let head):
            switch self.requestState {
            case .ready:
                /// Note: It is critical that `URI.init(path:)` is used here, _NOT_ `URI.init(string:)`. The following
                /// example illustrates why:
                ///
                ///     let uri1 = URI(string: "//foo/bar?a#b"), uri2 = URI(path: "//foo/bar?a#b")
                ///
                ///     print(uri1.host, uri1.path, uri1.query, uri1.fragment)
                ///     // Optional(foo) /bar a b
                ///     print(uri2.host, uri2.path, uri2.query, uri2.fragment)
                ///     // nil /foo/bar a b
                ///
                /// The latter parse has the correct semantics for an HTTP request's URL (which, in the absence of an
                /// accompanying scheme, should never have a host); the former follows strict RFC 3986 rules.
                let request = try! Request(
                    application: self.application,
                    method: .init(head.method),
                    url: .init(path: head.uri),
                    version: head.version,
                    headersNoUpdate: .init(head.headers, splitCookie: false),
                    remoteAddress: context.channel.remoteAddress,
                    logger: self.application.logger,
                    byteBufferAllocator: context.channel.allocator,
                    on: context.channel.eventLoop
                )
                switch head.version.major {
                case 2:
                    request.requestBox.withLockedValue { $0.isKeepAlive = true }
                default:
                    request.requestBox.withLockedValue { $0.isKeepAlive = head.isKeepAlive }
                }
                self.requestState = .awaitingBody(request)
            default: assertionFailure("Unexpected state: \(self.requestState)")
            }
        case .body(let buffer):
            switch self.requestState {
            case .ready, .awaitingEnd:
                assertionFailure("Unexpected state: \(self.requestState)")
            case .awaitingBody(let request):
                // We cannot assume that a request's content-length represents the length of all of the body
                // because when a request is g-zipped, content-length refers to the gzipped length.
                // Therefore, we can receive data after our expected end-of-request
                // When decompressing data, more bytes come out than came in, so content-length does not represent the maximum length
                if request.headers[.contentLength] == buffer.readableBytes.description {
                    self.requestState = .awaitingEnd(request, buffer)
                } else {
                    let stream = Request.BodyStream(on: context.eventLoop, byteBufferAllocator: context.channel.allocator)
                    request.bodyStorage.withLockedValue { $0 = .stream(stream) }
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
                request.bodyStorage.withLockedValue { $0 = .collected(buffer) }
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

        if error is HTTPParserError {
            self.logger.debug("Invalid HTTP request, will close connection: \(String(reflecting: error))")
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

    func handleBodyStreamStateResult(
        context: ChannelHandlerContext,
        _ result: HTTPBodyStreamState.Result,
        stream: Request.BodyStream
    ) {
        switch result.action {
        case .nothing: break
        case .write(let buffer):
            let box = NIOLoopBound((context, self), eventLoop: context.eventLoop)
            stream.write(.buffer(buffer)).whenComplete { writeResult in
                let (context, handler) = box.value
                switch writeResult {
                case .failure(let error):
                    handler.handleBodyStreamStateResult(
                        context: context,
                        handler.bodyStreamState.didError(error),
                        stream: stream
                    )
                case .success: break
                }
                handler.handleBodyStreamStateResult(
                    context: context,
                    handler.bodyStreamState.didWrite(),
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
        case is HTTPServerResponseEncoder.ResponseEndSentEvent:
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
            context.fireUserInboundEventTriggered(event)
        }
    }
}

extension NIOHTTP1.HTTPPart: Swift.CustomStringConvertible {
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
                bufferedWrites: .init(),
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
