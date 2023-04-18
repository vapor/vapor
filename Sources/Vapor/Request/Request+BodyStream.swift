import NIOCore
import NIOConcurrencyHelpers

extension Request {
    final class BodyStream: BodyStreamWriter, Sendable {
        let eventLoop: EventLoop

        var isBeingRead: Bool {
            self.handler.withLockedValue { $0 } != nil
        }

        // Ensure this can only be mutated from this class
        var isClosed: Bool {
            isClosedBox.withLockedValue { $0 }
        }
        private let isClosedBox: NIOLockedValueBox<Bool>
        typealias BodyStreamHandler = (@Sendable (BodyStreamResult, EventLoopPromise<Void>?) -> ())
        private let handler: NIOLockedValueBox<BodyStreamHandler?>
        private var buffer: [(BodyStreamResult, EventLoopPromise<Void>?)]
        private let allocator: ByteBufferAllocator

        init(on eventLoop: EventLoop, byteBufferAllocator: ByteBufferAllocator) {
            self.eventLoop = eventLoop
            self.isClosedBox = .init(false)
            self.buffer = []
            self.allocator = byteBufferAllocator
            self.handler = .init(nil)
        }

        func read(_ handler: @Sendable @escaping (BodyStreamResult, EventLoopPromise<Void>?) -> ()) {
            self.handler.withLockedValue { $0 = handler }
            for (result, promise) in self.buffer {
                handler(result, promise)
            }
            self.buffer = []
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
                self.isClosedBox.withLockedValue { $0 = true }
            case .buffer: break
            }
            
            if let handler = self.handler.withLockedValue({ $0 }) {
                handler(chunk, promise)
                // remove reference to handler
                switch chunk {
                case .end, .error:
                    self.handler.withLockedValue { $0 = nil }
                default: break
                }
            } else {
                self.buffer.append((chunk, promise))
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
            assert(self.isClosed, "Request.BodyStream deinitialized before closing.")
        }
    }
}
