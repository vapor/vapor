import NIOCore
import NIOConcurrencyHelpers

extension Request {
    final class BodyStream: BodyStreamWriter, AsyncBodyStreamWriter {
        let eventLoop: EventLoop

        var isBeingRead: Bool {
            self.handler != nil
        }

        private(set) var isClosed: Bool
        private var handler: ((BodyStreamResult, EventLoopPromise<Void>?) -> ())?
        private var buffer: [(BodyStreamResult, EventLoopPromise<Void>?)]
        private let allocator: ByteBufferAllocator

        init(on eventLoop: EventLoop, byteBufferAllocator: ByteBufferAllocator) {
            self.eventLoop = eventLoop
            self.isClosed = false
            self.buffer = []
            self.allocator = byteBufferAllocator
        }

        func read(_ handler: @escaping (BodyStreamResult, EventLoopPromise<Void>?) -> ()) {
            self.handler = handler
            for (result, promise) in self.buffer {
                handler(result, promise)
            }
            self.buffer = []
        }
        
        func write(_ result: BodyStreamResult) async throws {
            // Explicitly adds the ELF because Swift 5.6 fails to infer the return type
            try await self.eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
                let promise = self.eventLoop.makePromise(of: Void.self)
                self.write0(result, promise: promise)
                return promise.futureResult
            }.get()
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
                self.isClosed = true
            case .buffer: break
            }
            
            if let handler = self.handler {
                handler(chunk, promise)
                // remove reference to handler
                switch chunk {
                case .end, .error:
                    self.handler = nil
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
                var data = self.allocator.buffer(capacity: 0)
                self.read { chunk, next in
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
            assert(self.isClosed, "Request.BodyStream deinitialized before closing.")
        }
    }
}
