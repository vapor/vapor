import NIOCore
import NIOConcurrencyHelpers

extension Request {
    final class BodyStream: BodyStreamWriter {
        let eventLoop: EventLoop

        var isBeingRead: Bool {
            self.handlerBuffer.value.handler != nil
        }
        
        struct HandlerBufferContainer: Sendable {
            var handler: (@Sendable (BodyStreamResult, EventLoopPromise<Void>?) -> ())?
            var buffer: [(BodyStreamResult, EventLoopPromise<Void>?)]
        }

        #warning("Again does this need to be sendable")
        private let isClosed: NIOLockedValueBox<Bool>
        private let handlerBuffer: NIOLoopBoundBox<HandlerBufferContainer>
        private let allocator: ByteBufferAllocator

        init(on eventLoop: EventLoop, byteBufferAllocator: ByteBufferAllocator) {
            self.eventLoop = eventLoop
            self.isClosed = .init(false)
            self.handlerBuffer = .init(.init(handler: nil, buffer: []), eventLoop: eventLoop)
            self.allocator = byteBufferAllocator
        }

        func read(_ handler: @Sendable @escaping (BodyStreamResult, EventLoopPromise<Void>?) -> ()) {
            self.handlerBuffer.value.handler = handler
            for (result, promise) in self.handlerBuffer.value.buffer {
                handler(result, promise)
            }
            self.handlerBuffer.value.buffer = []
        }

        func write(_ chunk: BodyStreamResult, promise: EventLoopPromise<Void>?) {
            // See https://github.com/vapor/vapor/issues/2906
            if self.eventLoop.inEventLoop {
                write0(chunk, promise: promise)
            } else {
                self.eventLoop.execute {
                    self.write0(chunk, promise: promise)
                }
            }
        }
        
        private func write0(_ chunk: BodyStreamResult, promise: EventLoopPromise<Void>?) {
            switch chunk {
            case .end, .error:
                self.isClosed.withLockedValue { $0 = true }
            case .buffer: break
            }
            
            if let handler = self.handlerBuffer.value.handler {
                handler(chunk, promise)
                // remove reference to handler
                switch chunk {
                case .end, .error:
                    self.handlerBuffer.value.handler = nil
                default: break
                }
            } else {
                self.handlerBuffer.value.buffer.append((chunk, promise))
            }
        }

        func consume(max: Int?, on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
            // See https://github.com/vapor/vapor/issues/2906
            return eventLoop.flatSubmit {
                let promise = eventLoop.makePromise(of: ByteBuffer.self)
                let dataBox = NIOLoopBoundBox(self.allocator.buffer(capacity: 0), eventLoop: eventLoop)
                self.read { chunk, next in
                    var data = dataBox.value
                    switch chunk {
                    case .buffer(var buffer):
                        if let max = max, data.readableBytes + buffer.readableBytes >= max {
                            promise.fail(Abort(.payloadTooLarge))
                        } else {
                            data.writeBuffer(&buffer)
                        }
                    case .error(let error): promise.fail(error)
                    case .end: promise.succeed(data)
                    }
                    next?.succeed(())
                }
                
                return promise.futureResult
            }
        }

        deinit {
            assert(self.isClosed.withLockedValue { $0 }, "Request.BodyStream deinitialized before closing.")
        }
    }
}
