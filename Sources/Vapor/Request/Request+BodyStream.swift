import NIOCore
import NIOConcurrencyHelpers

extension Request {
    final class BodyStream: BodyStreamWriter, Sendable {
        let eventLoop: EventLoop
        
        var isBeingRead: Bool {
            self.handler != nil
        }

        var isBeingRead2: Bool {
            get {
//                return self.handler2.withLockedValue { $0 != nil }
    //            self.handler.withLockedValue { $0 } != nil
//                return false
                return self.handler2 != nil
            }
        }
        
//        func getHandlerValue() -> BodyStreamHandler? {
//            return self.handler2.withLockedValue { $0 }
//        }

        // Ensure this can only be mutated from this class
        var isClosed: Bool {
            isClosedBox.withLockedValue { $0 }
        }
        private let isClosedBox: NIOLockedValueBox<Bool>
        typealias BodyStreamHandler = (@Sendable (BodyStreamResult, EventLoopPromise<Void>?) -> ())
//        private let handler2: NIOLockedValueBox2<BodyStreamHandler?>
        private let handlerLock: NIOLock
        private var _handler2: BodyStreamHandler?
        private var handler2: BodyStreamHandler? {
            get {
                handlerLock.withLock {
                    return _handler2
                }
            }
            set {
                handlerLock.withLockVoid {
                    _handler2 = newValue
                }
            }
        }
        private var handler: BodyStreamHandler?
        private let buffer: NIOLockedValueBox<[(BodyStreamResult, EventLoopPromise<Void>?)]>
        private let allocator: ByteBufferAllocator

        init(on eventLoop: EventLoop, byteBufferAllocator: ByteBufferAllocator) {
            self.eventLoop = eventLoop
            self.isClosedBox = .init(false)
            self.buffer = .init([])
            self.allocator = byteBufferAllocator
//            self.handler2 = .init(nil)
            self.handlerLock = .init()
        }

        func read(_ handler: @Sendable @escaping (BodyStreamResult, EventLoopPromise<Void>?) -> ()) {
//            self.handler2.withLockedValue { $0 = handler }
            self.handler2 = handler
            self.handler = handler
            for (result, promise) in self.buffer.withLockedValue({ $0 }) {
                handler(result, promise)
            }
            self.buffer.withLockedValue { $0 = [] }
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
            
//            if let handler = self.handler.withLockedValue({ $0 }) {
            if let handler = self.handler {
                handler(chunk, promise)
                // remove reference to handler
                switch chunk {
                case .end, .error:
//                    self.handler2.withLockedValue { $0 = nil }
                    self.handler2 = nil
                    self.handler = nil
                default: break
                }
            } else {
                self.buffer.withLockedValue { $0.append((chunk, promise)) }
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
