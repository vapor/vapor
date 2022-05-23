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
                let buffer = context.channel.allocator.buffer(string: string)
                self.writeAndflush(buffer: buffer, context: context, promise: promise)
            case .staticString(let string):
                let buffer = context.channel.allocator.buffer(staticString: string)
                self.writeAndflush(buffer: buffer, context: context, promise: promise)
            case .data(let data):
                let buffer = context.channel.allocator.buffer(bytes: data)
                self.writeAndflush(buffer: buffer, context: context, promise: promise)
            case .dispatchData(let data):
                let buffer = context.channel.allocator.buffer(dispatchData: data)
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

private final class ChannelResponseBodyStream: BodyStreamWriter {
    let context: ChannelHandlerContext
    let handler: HTTPServerResponseEncoder
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
        handler: HTTPServerResponseEncoder,
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
            self.context.fireUserInboundEventTriggered(HTTPServerResponseEncoder.ResponseEndSentEvent())
            self.context.writeAndFlush(self.handler.wrapOutboundOut(.end(nil)), promise: promise)
            self.promise?.succeed(())
        case .error(let error):
            self.isComplete = true
            self.context.fireUserInboundEventTriggered(HTTPServerResponseEncoder.ResponseEndSentEvent())
            self.context.writeAndFlush(self.handler.wrapOutboundOut(.end(nil)), promise: promise)
            self.promise?.fail(error)
        }
    }

    deinit {
        assert(self.isComplete, "Response body stream writer deinitialized before .end or .error was sent.")
    }
}
