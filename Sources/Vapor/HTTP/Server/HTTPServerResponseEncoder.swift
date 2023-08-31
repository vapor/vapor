import NIOCore
import NIOHTTP1
import NIOConcurrencyHelpers
import Atomics

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
    let contextBox: NIOLoopBound<ChannelHandlerContext>
    let handlerBox: NIOLoopBound<HTTPServerResponseEncoder>
    let promise: EventLoopPromise<Void>?
    let count: Int?
    let currentCount: ManagedAtomic<Int>
    let isComplete: ManagedAtomic<Bool>
    let eventLoop: EventLoop

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
        self.contextBox = .init(context, eventLoop: context.eventLoop)
        self.handlerBox = .init(handler, eventLoop: context.eventLoop)
        self.promise = promise
        self.count = count
        self.currentCount = .init(0)
        self.isComplete = .init(false)
        self.eventLoop = context.eventLoop
    }
    
    func write(_ result: BodyStreamResult, promise: EventLoopPromise<Void>?) {
        switch result {
        case .buffer(let buffer):
            self.contextBox.value.writeAndFlush(self.handlerBox.value.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: promise)
            self.currentCount.wrappingIncrement(by: buffer.readableBytes, ordering: .sequentiallyConsistent)
            if let count = self.count, self.currentCount.load(ordering: .sequentiallyConsistent) > count {
                self.promise?.fail(Error.tooManyBytes)
                promise?.fail(Error.notEnoughBytes)
            }
        case .end:
            self.isComplete.store(true, ordering: .relaxed)
            if let count = self.count, self.currentCount.load(ordering: .sequentiallyConsistent) != count {
                self.promise?.fail(Error.notEnoughBytes)
                promise?.fail(Error.notEnoughBytes)
            }
            self.contextBox.value.fireUserInboundEventTriggered(HTTPServerResponseEncoder.ResponseEndSentEvent())
            self.contextBox.value.writeAndFlush(self.handlerBox.value.wrapOutboundOut(.end(nil)), promise: promise)
            self.promise?.succeed(())
        case .error(let error):
            self.isComplete.store(true, ordering: .relaxed)
            self.contextBox.value.fireUserInboundEventTriggered(HTTPServerResponseEncoder.ResponseEndSentEvent())
            self.contextBox.value.writeAndFlush(self.handlerBox.value.wrapOutboundOut(.end(nil)), promise: promise)
            self.promise?.fail(error)
        }
    }

    deinit {
        assert(self.isComplete.load(ordering: .sequentiallyConsistent), "Response body stream writer deinitialized before .end or .error was sent.")
    }
}
