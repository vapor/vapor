package import NIOCore
import Synchronization

/// A one-chunk handoff between a body-stream closure and an `AsyncSequence`.
///
/// Vapor's body streams *push*: the closure is handed a writer and calls `write` for each chunk.
/// AsyncHTTPClient *pulls*: it asks an `AsyncSequence` for the next `ByteBuffer` when the connection
/// has room. This is the join between the two, and the reason it is a handoff rather than a buffer is
/// backpressure — ``send(_:)`` does not return until the consumer has taken the chunk, so a fast
/// producer suspends against a slow connection instead of queueing into memory.
///
/// Single-producer, single-consumer: the producer is the body-stream closure, the consumer is AHC.
package final class ChunkHandoff: Sendable {
    /// Why the stream stopped, once it has.
    private enum Terminal {
        case finished
        case failed(any Error)
    }

    private struct State {
        /// A chunk the producer has offered and no consumer has taken yet.
        var pending: ByteBuffer?
        /// The producer, parked until its offered chunk is taken.
        var producer: CheckedContinuation<Void, any Error>?
        /// The consumer, parked until a chunk is offered or the stream ends.
        var consumer: CheckedContinuation<ByteBuffer?, any Error>?
        var terminal: Terminal?
    }
    private let state = Mutex(State())

    package init() {}

    /// Offers one chunk, returning once the consumer has taken it.
    ///
    /// Cancelling the producing task ends the whole handoff: a parked producer would otherwise wait
    /// for a consumer that is never coming, and leak a suspended task with it.
    package func send(_ chunk: ByteBuffer) async throws {
        try await withTaskCancellationHandler {
            try await self.offer(chunk)
        } onCancel: {
            self.finish(throwing: CancellationError())
        }
    }

    private func offer(_ chunk: ByteBuffer) async throws {
        try await withCheckedThrowingContinuation { (producer: CheckedContinuation<Void, any Error>) in
            enum Resume {
                case handOver(CheckedContinuation<ByteBuffer?, any Error>)
                case park
                case stop(any Error)
            }
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
                break // resumed by `next()` when the chunk is taken
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
        let (consumer, producer): (CheckedContinuation<ByteBuffer?, any Error>?, CheckedContinuation<Void, any Error>?) =
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
    fileprivate func next() async throws -> ByteBuffer? {
        try await withCheckedThrowingContinuation { (consumer: CheckedContinuation<ByteBuffer?, any Error>) in
            enum Take {
                case chunk(ByteBuffer, CheckedContinuation<Void, any Error>?)
                case park
                case end
                case fail(any Error)
            }
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
                break // resumed by `send(_:)` or `finish(throwing:)`
            case .end:
                consumer.resume(returning: nil)
            case .fail(let error):
                consumer.resume(throwing: error)
            }
        }
    }
}

/// The `AsyncSequence` face of a ``ChunkHandoff``, which is what AsyncHTTPClient consumes.
package struct ChunkHandoffSequence: AsyncSequence, Sendable {
    package typealias Element = ByteBuffer

    package let handoff: ChunkHandoff

    package init(handoff: ChunkHandoff) {
        self.handoff = handoff
    }

    package struct AsyncIterator: AsyncIteratorProtocol {
        let handoff: ChunkHandoff
        package func next() async throws -> ByteBuffer? {
            try await self.handoff.next()
        }
    }

    package func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(handoff: self.handoff)
    }
}
