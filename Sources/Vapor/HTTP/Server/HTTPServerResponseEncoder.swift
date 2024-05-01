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
        var headOrNoContentRequest = false
        response.responseBox.withLockedValue { box in
            // add a RFC1123 timestamp to the Date header to make this
            // a valid request
            box.headers.add(name: "date", value: self.dateCache.currentTimestamp())
            if let server = self.serverHeader {
                box.headers.add(name: "server", value: server)
            }
            
            // begin serializing
            let responseHead = HTTPResponseHead(version: box.version, status: box.status, headers: box.headers)
            context.write(wrapOutboundOut(.head(responseHead)), promise: nil)
            
            if box.status == .noContent || box.forHeadRequest {
                headOrNoContentRequest = true
            }
        }
        
        if headOrNoContentRequest {
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
            case .asyncStream(let stream):
                let channelStream = ChannelResponseBodyStream(
                    context: context,
                    handler: self,
                    promise: promise,
                    count: stream.count == -1 ? nil : stream.count
                )
                
                Task {
                    do {
                        try await stream.callback(channelStream)
                    } catch {
                        promise?.fail(error)
                    }
                }
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

private final class ChannelResponseBodyStream: BodyStreamWriter, AsyncBodyStreamWriter {
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
    
    func write(_ result: BodyStreamResult) async throws {
        // Explicitly adds the ELF because Swift 5.6 fails to infer the return type
        try await self.eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            let promise = self.eventLoop.makePromise(of: Void.self)
            self.write(result, promise: promise)
            return promise.futureResult
        }.get()
    }
    
    func write(_ result: BodyStreamResult, promise: EventLoopPromise<Void>?) {
        switch result {
        case .buffer(let buffer):
            // See: https://github.com/vapor/vapor/issues/2976
            self.contextBox.value.writeAndFlush(self.handlerBox.value.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: promise)
            if let count = self.count, self.currentCount.wrappingIncrementThenLoad(by: buffer.readableBytes, ordering: .sequentiallyConsistent) > count {
                self.promise?.fail(Error.tooManyBytes)
                promise?.fail(Error.notEnoughBytes)
            }
        case .end:
            // See: https://github.com/vapor/vapor/issues/2976
            self.isComplete.store(true, ordering: .sequentiallyConsistent)
            if let count = self.count, self.currentCount.load(ordering: .sequentiallyConsistent) < count {
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
