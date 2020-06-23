import NIO
import NIOHTTP1

final class HTTPServerResponseEncoder: ChannelOutboundHandler, RemovableChannelHandler {
    typealias OutboundIn = Response
    typealias OutboundOut = HTTPServerResponsePart
    
    /// Optional server header.
    private let serverHeader: String?
    private let dateCache: RFC1123DateCache

    struct ResponseEndSentEvent { }
    
    init(serverHeader: String?, dateCache: RFC1123DateCache) {
        self.serverHeader = serverHeader
        self.dateCache = dateCache
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
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: promise)
            context.fireUserInboundEventTriggered(ResponseEndSentEvent())
        } else {
            switch response.body.storage {
            case .none:
                context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)
                context.fireUserInboundEventTriggered(ResponseEndSentEvent())
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
                    count: stream.count
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
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)
        context.fireUserInboundEventTriggered(ResponseEndSentEvent())
    }
}

private final class ChannelResponseBodyStream: BodyStreamWriter {
    let context: ChannelHandlerContext
    let handler: HTTPServerResponseEncoder
    let promise: EventLoopPromise<Void>?
    let count: Int
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
        handler: HTTPServerResponseEncoder,
        promise: EventLoopPromise<Void>?,
        count: Int
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
            guard self.currentCount <= self.count else {
                self.promise?.fail(Error.tooManyBytes)
                promise?.fail(Error.notEnoughBytes)
                return
                // self.context.close(promise: nil)
            }
        case .end:
            self.isComplete = true
            guard self.currentCount == self.count else {
                self.promise?.fail(Error.notEnoughBytes)
                promise?.fail(Error.notEnoughBytes)
                return
                // self.context.close(promise: nil)
            }
            self.context.writeAndFlush(self.handler.wrapOutboundOut(.end(nil)), promise: promise)
            self.context.fireUserInboundEventTriggered(HTTPServerResponseEncoder.ResponseEndSentEvent())
            self.promise?.succeed(())
        case .error(let error):
            self.isComplete = true
            self.context.writeAndFlush(self.handler.wrapOutboundOut(.end(nil)), promise: promise)
            self.context.fireUserInboundEventTriggered(HTTPServerResponseEncoder.ResponseEndSentEvent())
            self.promise?.fail(error)
        }
    }

    deinit {
        assert(self.isComplete, "Response body stream writer deinitialized before .end or .error was sent.")
    }
}
