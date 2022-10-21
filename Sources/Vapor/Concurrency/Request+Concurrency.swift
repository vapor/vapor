#if compiler(>=5.5) && canImport(_Concurrency)
import NIOCore
import NIOConcurrencyHelpers

// MARK: - Request.Body.AsyncSequenceDelegate
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Request.Body {
    
    /// `Request.Body.AsyncSequenceDelegate` bridges between EventLoop
    /// and AsyncSequence. Crucially, this type handles backpressure
    /// by synchronizing bytes on the `EventLoop`
    ///
    /// `AsyncSequenceDelegate` can be created and **must be retained**
    /// in `Request.Body/makeAsyncIterator()` method.
    fileprivate final class AsyncSequenceDelegate: @unchecked Sendable, NIOAsyncSequenceProducerDelegate {
        private enum State {
            case noSignalReceived
            case waitingForSignalFromConsumer(EventLoopPromise<Void>)
        }

        private var _state: State = .noSignalReceived
        private let eventLoop: any EventLoop

        init(eventLoop: any EventLoop) {
            self.eventLoop = eventLoop
        }

        private func produceMore0() {
            self.eventLoop.preconditionInEventLoop()
            switch self._state {
            case .noSignalReceived:
                preconditionFailure()
            case .waitingForSignalFromConsumer(let promise):
                self._state = .noSignalReceived
                promise.succeed(())
            }
        }

        private func didTerminate0() {
            self.eventLoop.preconditionInEventLoop()
            switch self._state {
            case .noSignalReceived:
                // we will inform the producer, since the next write will fail.
                break
            case .waitingForSignalFromConsumer(let promise):
                self._state = .noSignalReceived
                promise.fail(CancellationError())
            }
        }

        func registerBackpressurePromise(_ promise: EventLoopPromise<Void>) {
            self.eventLoop.preconditionInEventLoop()
            switch self._state {
            case .noSignalReceived:
                self._state = .waitingForSignalFromConsumer(promise)
            case .waitingForSignalFromConsumer:
                preconditionFailure()
            }
        }

        func didTerminate() {
            self.eventLoop.execute { self.didTerminate0() }
        }

        func produceMore() {
            self.eventLoop.execute { self.produceMore0() }
        }
    }
}

// MARK: - Request.Body.AsyncSequence
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Request.Body: AsyncSequence {
    public typealias Element = ByteBuffer
    
    /// This wrapper generalizes our implementation
    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = ByteBuffer

        fileprivate typealias Underlying = NIOThrowingAsyncSequenceProducer<ByteBuffer, any Error, NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark, Request.Body.AsyncSequenceDelegate>.AsyncIterator

        private var underlying: Underlying

        fileprivate init(underlying: Underlying) {
            self.underlying = underlying
        }

        public mutating func next() async throws -> ByteBuffer? {
            print("2. next")
            return try await self.underlying.next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        switch request.bodyStorage {
        case .stream(_):
            // TODO: Remove debugging before merge
            print("1. stream")
            break
        case .collected(_):
            // TODO: Remove debugging before merge
            print("1. collected")
            break
        default:
            preconditionFailure("""
            AsyncSequence streaming should use a body of type .stream()
            Example: app.on(.POST, "/upload", body: .stream) { ... }
           """)
        }
        let delegate = AsyncSequenceDelegate(eventLoop: request.eventLoop)
        
        let producer = NIOThrowingAsyncSequenceProducer.makeSequence(
            elementType: ByteBuffer.self,
            failureType: Error.self,
            backPressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies
                .HighLowWatermark(lowWatermark: 5, highWatermark: 20),
            delegate: delegate
        )
        
        let source = producer.source
        
        self.drain { streamResult in
            switch streamResult {
            case .buffer(let buffer):
                print("3. buff")
                // hand over the buffer to the async sequence
                let result = source.yield(buffer)
                // inspect what the source view and handle outcomes
                switch result {
                case .dropped:
                    // the consumer dropped the sequence
                    // we must inform the producer that we don't want more data.
                    // we do this by returning an error in the future.
                    return request.eventLoop.makeFailedFuture(CancellationError())
                case .stopProducing:
                    // the consumer is consuming fast enough for us. we need to create a promise that we succeed later.
                    let promise = request.eventLoop.makePromise(of: Void.self)
                    // we pass the promise to the delegate so that we can succeed it, once we get a call to delegate.produceMore
                    delegate.registerBackpressurePromise(promise)
                    // return the future that we will fulfill eventually.
                    return promise.futureResult
                case .produceMore:
                    // we can produce more immidiatly. return a succeeded future.
                    return request.eventLoop.makeSucceededVoidFuture()
                }
            case .error(let error):
                source.finish(error)
                return request.eventLoop.makeSucceededVoidFuture()
            case .end:
                print("4. end")
                source.finish()
                return request.eventLoop.makeSucceededVoidFuture()
            }
        }
        
        return AsyncIterator(underlying: producer.sequence.makeAsyncIterator())
    }
}
#endif
