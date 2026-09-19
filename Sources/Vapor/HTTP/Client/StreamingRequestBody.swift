import Synchronization

/// A one-chunk handoff between a body-stream closure and an `AsyncSequence`. Bridge between AHC and Vapor's body streams to support backpressure
///
/// Single-producer, single-consumer: the producer is the body-stream closure, the consumer is AHC.
package final class ChunkHandoff<Chunk: Sendable>: Sendable {
    /// Why the stream stopped, once it has.
    private enum Terminal {
        case finished
        case failed(any Error)
    }

    private struct State {
        /// A chunk the producer has offered and no consumer has taken yet.
        var pending: Chunk?
        /// The producer, parked until its offered chunk is taken.
        var producer: CheckedContinuation<Void, any Error>?
        /// The consumer, parked until a chunk is offered or the stream ends.
        var consumer: CheckedContinuation<Chunk?, any Error>?
        var terminal: Terminal?
    }
    private let state = Mutex(State())

    /// What ``offer(_:)`` decided under the lock: hand the chunk to a waiting consumer, park until one
    /// takes it, or stop because the stream has already ended.
    private enum Resume {
        case handOver(CheckedContinuation<Chunk?, any Error>)
        case park
        case stop(any Error)
    }

    /// What ``next()`` decided under the lock: take the pending chunk (waking its producer), park until
    /// one is offered, report the end, or rethrow the failure.
    private enum Take {
        case chunk(Chunk, CheckedContinuation<Void, any Error>?)
        case park
        case end
        case fail(any Error)
    }

    package init() {}

    /// Offers one chunk, returning once the consumer has taken it.
    ///
    /// Cancelling the producing task ends the whole handoff: a parked producer would otherwise wait
    /// for a consumer that is never coming, and leak a suspended task with it.
    package func send(_ chunk: Chunk) async throws {
        try await withTaskCancellationHandler {
            try await self.offer(chunk)
        } onCancel: {
            self.finish(throwing: CancellationError())
        }
    }

    private func offer(_ chunk: Chunk) async throws {
        try await withCheckedThrowingContinuation { (producer: CheckedContinuation<Void, any Error>) in
            let action: Resume = self.state.withLock { state in
                if case .failed(let error) = state.terminal { return .stop(error) }
                if state.terminal != nil { return .stop(CancellationError()) }
                if let waiting = state.consumer.take() { return .handOver(waiting) }
                state.pending = chunk
                state.producer = producer
                return .park
            }
            switch action {
            case .handOver(let consumer):
                // Somebody was already waiting, so the chunk is taken the moment we pass it on.
                consumer.resume(returning: chunk)
                producer.resume()
            case .park:
                break  // resumed by `next()` when the chunk is taken
            case .stop(let error):
                producer.resume(throwing: error)
            }
        }
    }

    /// Ends the stream, either normally or because the producer threw or was cancelled.
    ///
    /// Wakes whichever side is parked. A consumer sees the end; a producer still waiting for its
    /// chunk to be taken is failed, because nothing is going to take it now.
    package func finish(throwing error: (any Error)? = nil) {
        let (consumer, producer): (CheckedContinuation<Chunk?, any Error>?, CheckedContinuation<Void, any Error>?) =
            self.state.withLock { state in
                guard state.terminal == nil else { return (nil, nil) }
                state.terminal = error.map { Terminal.failed($0) } ?? .finished
                state.pending = nil
                return (state.consumer.take(), state.producer.take())
            }
        if let consumer {
            if let error {
                consumer.resume(throwing: error)
            } else {
                consumer.resume(returning: nil)
            }
        }
        producer?.resume(throwing: error ?? CancellationError())
    }

    /// Takes the next chunk, or `nil` once the producer has finished.
    fileprivate func next() async throws -> Chunk? {
        try await withCheckedThrowingContinuation { (consumer: CheckedContinuation<Chunk?, any Error>) in
            let action: Take = self.state.withLock { state in
                if let chunk = state.pending.take() { return .chunk(chunk, state.producer.take()) }
                switch state.terminal {
                case .failed(let error): return .fail(error)
                case .finished: return .end
                case nil:
                    state.consumer = consumer
                    return .park
                }
            }
            switch action {
            case .chunk(let chunk, let producer):
                consumer.resume(returning: chunk)
                producer?.resume()
            case .park:
                break  // resumed by `send(_:)` or `finish(throwing:)`
            case .end:
                consumer.resume(returning: nil)
            case .fail(let error):
                consumer.resume(throwing: error)
            }
        }
    }
}

/// The `AsyncSequence` face of a ``ChunkHandoff``, which is what AsyncHTTPClient consumes.
package struct ChunkHandoffSequence<Chunk: Sendable>: AsyncSequence, Sendable {
    package typealias Element = Chunk

    package let handoff: ChunkHandoff<Chunk>

    package init(handoff: ChunkHandoff<Chunk>) {
        self.handoff = handoff
    }

    package struct AsyncIterator: AsyncIteratorProtocol {
        let handoff: ChunkHandoff<Chunk>
        package func next() async throws -> Chunk? {
            try await self.handoff.next()
        }
    }

    package func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(handoff: self.handoff)
    }
}
