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

    struct BodyStreamState: CustomStringConvertible {
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

        mutating func write(_ buffer: ByteBuffer) -> Result {
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

        mutating func read() -> Result {
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

        mutating func close() -> Result {
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

    var requestState: RequestState
    var bodyStreamState: BodyStreamState

    private let logger: Logger
    var application: Application
    
    init(application: Application) {
        self.application = application
        self.requestState = .ready
        self.logger = Logger(label: "codes.vapor.server")
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
                self.handleBodyStreamStateResult(
                    context: context,
                    self.bodyStreamState.write(previousBuffer),
                    stream: stream
                )
                self.handleBodyStreamStateResult(
                    context: context,
                    self.bodyStreamState.write(buffer),
                    stream: stream
                )
                self.requestState = .streamingBody(stream)
            case .streamingBody(let stream):
                self.handleBodyStreamStateResult(
                    context: context,
                    self.bodyStreamState.write(buffer),
                    stream: stream
                )
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
                    self.bodyStreamState.close(),
                    stream: stream
                )
            }
            self.requestState = .ready
        }
    }

    func read(context: ChannelHandlerContext) {
        switch self.requestState {
        case .streamingBody(let stream):
            self.handleBodyStreamStateResult(
                context: context,
                self.bodyStreamState.read(),
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
        context.fireErrorCaught(error)
    }

    func handleBodyStreamStateResult(
        context: ChannelHandlerContext,
        _ result: BodyStreamState.Result,
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
                case .success:
                    self.handleBodyStreamStateResult(
                        context: context,
                        self.bodyStreamState.didWrite(),
                        stream: stream
                    )
                }
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
}
