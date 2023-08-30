import NIOCore
import NIOConcurrencyHelpers

extension Request {
    final class BodyStream: BodyStreamWriter {
        let eventLoop: EventLoop

        var isBeingRead: Bool {
            self.handlerBuffer.withLockedValue { $0.handler != nil }
        }
        
        struct HandlerBufferContainer: Sendable {
            var handler: (@Sendable (BodyStreamResult, EventLoopPromise<Void>?) -> ())?
            var buffer: [(BodyStreamResult, EventLoopPromise<Void>?)]
        }

        private let isClosed: NIOLockedValueBox<Bool>
        private let handlerBuffer: NIOLockedValueBox<HandlerBufferContainer>
        private let allocator: ByteBufferAllocator

        init(on eventLoop: EventLoop, byteBufferAllocator: ByteBufferAllocator) {
            self.eventLoop = eventLoop
            self.isClosed = .init(false)
            self.handlerBuffer = .init(.init(handler: nil, buffer: []))
            self.allocator = byteBufferAllocator
        }

        func read(_ handler: @Sendable @escaping (BodyStreamResult, EventLoopPromise<Void>?) -> ()) {
            self.handlerBuffer.withLockedValue {
                $0.handler = handler
                for (result, promise) in $0.buffer {
                    handler(result, promise)
                }
                $0.buffer = []
            }
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
            
            self.handlerBuffer.withLockedValue {
                if let handler = $0.handler {
                    handler(chunk, promise)
                    // remove reference to handler
                    switch chunk {
                    case .end, .error:
                        $0.handler = nil
                    default: break
                    }
                } else {
                    $0.buffer.append((chunk, promise))
                }
            }
        }

        func consume(max: Int?, on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
            // See https://github.com/vapor/vapor/issues/2906
            return eventLoop.flatSubmit {
                let promise = eventLoop.makePromise(of: ByteBuffer.self)
                let data = NIOLoopBoundBox(self.allocator.buffer(capacity: 0), eventLoop: eventLoop)
                self.read { chunk, next in
                    switch chunk {
                    case .buffer(var buffer):
                        if let max = max, data.value.readableBytes + buffer.readableBytes >= max {
                            promise.fail(Abort(.payloadTooLarge))
                        } else {
                            data.value.writeBuffer(&buffer)
                        }
                    case .error(let error): promise.fail(error)
                    case .end: promise.succeed(data.value)
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
