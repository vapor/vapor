import BasicContainers
import NIOHTTPServer
import Synchronization

#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

/// Holds the server's move-only, non-`Sendable` request `Reader` behind a `Mutex`, so it can live in `Request
///
/// A body is single-consumer: a read that finds the reader already checked out throws
/// ``RequestBodyAlreadyBeingRead`` rather than silently reporting end-of-body.
package final class RequestBodyStream: Sendable {
    /// The reader plus its end latch. `~Copyable` because the `Reader` is move-only.
    private struct State: ~Copyable {
        /// The server's reader, or `nil` while a read has it checked out. Boxed in its own `Mutex`
        /// because that box is the one proof-carrying way back in (see the type-level note); the box is
        /// only ever touched while `RequestBodyStream.state` is held, so its lock is never contended.
        var reader: Mutex<NIOHTTPServer.Reader?>?
        /// The spare chunk buffer, ping-ponged with the server's reusable one on every read so neither
        /// side allocates per chunk. `nil` while a read has it checked out.
        var chunk: UniqueArray<UInt8>?
        /// An already-materialised body waiting to be handed over once, for a stream built with
        /// ``init(collected:)``. A request whose body never came off a socket — one the in-memory
        /// test client made, or one built by hand — still has to read like any other.
        var replay: Data?
        var finished = false
        /// Latched when a *transport* read fails. The stream's position is then unknown, so every
        /// later read throws rather than reporting a clean end-of-body on a truncated body. A failing
        /// *consumer* closure does not latch this: the read itself completed, the consumer merely
        /// stopped, and the stream is still positioned for whoever reads next.
        var failed = false
        /// Set while a ``collect(max:)`` owns the whole stream. Checked in the same lock acquisition
        /// that sets it, because "has anything been consumed yet?" asked on its own is a race: two
        /// collectors both see nothing consumed, both proceed, and the loser silently gets an empty
        /// body instead of an error.
        var collecting = false
        /// Body bytes handed to a consumer so far. Serves two callers: ``collect(max:)`` refuses a
        /// stream somebody else already took bytes from, and metrics can report a body size for a
        /// request nothing ever collected.
        var consumed = 0
    }
    private let state: Mutex<State>

    /// The result of checking the reader out of the lock: ours to read, already ended, or held by
    /// another task. `~Copyable` because it may carry the move-only `Reader`.
    private enum Checkout: ~Copyable {
        /// The reader and the spare chunk buffer are ours for this read.
        case reader(NIOHTTPServer.Reader, UniqueArray<UInt8>)
        /// A pre-collected body, handed over whole on this read.
        case replay(Data)
        /// The body already ended; signal end-of-body.
        case ended
        /// Another task holds the reader (single-consumer contract violated).
        case busy
        /// A transport read failed earlier; the stream's position is unknown.
        case failed
    }

    init(reader: consuming sending NIOHTTPServer.Reader) {
        self.state = Mutex(State(reader: Mutex(reader), chunk: UniqueArray()))
    }

    /// A stream over a body that is already in memory, which replays it as a single chunk.
    ///
    /// There is no reader and nothing to drain: reading one of these is pure book-keeping. It exists
    /// so that ``Request/Body/withReader(_:)`` and ``Request/Body/forEachChunk(_:)`` behave the same
    /// whether the body arrived on a socket, was collected earlier, or was never streamed at all.
    /// An empty or absent body delivers no chunks, matching ``Response/Body/withStreamingBytes(_:)``.
    init(collected: Data?) {
        let pending = (collected?.isEmpty == false) ? collected : nil
        self.state = Mutex(State(reader: nil, chunk: nil, replay: pending, finished: pending == nil))
    }

    /// Reads one part of the body, handing its bytes to `body` as a borrowed `Span<UInt8>` plus a flag
    /// that is `true` at end-of-body (the span is then empty). The single primitive behind
    /// ``collect(max:)``, ``drain(max:)`` and ``RequestBodyReader``. The span borrows this stream's
    /// chunk buffer, so it is valid only for the call — copy out what you keep.
    func read<R>(_ body: (Span<UInt8>, Bool) async throws -> R) async throws -> R {
        // Check the reader out of the lock (synchronously); the `await`s below happen outside it.
        let checkout = self.state.withLock { state -> sending Checkout in
            if state.failed { return .failed }
            if state.finished { return .ended }
            if let pending = state.replay.take() {
                // One chunk, then end on the next read — the same two-step shape a socket body has.
                state.finished = true
                state.consumed += pending.count
                return .replay(pending)
            }
            guard let box = state.reader.take(), let reader = box.withLock({ $0.take() }) else {
                // Not finished, yet the reader is gone: another task is mid-read.
                return .busy
            }
            return .reader(reader, state.chunk.take() ?? UniqueArray())
        }
        switch consume checkout {
        case .ended:
            return try await signalEndOfBody(to: body)
        case .busy:
            throw RequestBodyAlreadyBeingRead()
        case .failed:
            throw RequestBodyReadFailed()
        case .replay(let pending):
            // The `Data` owns its bytes and lives for the duration of the call, so its span goes
            // straight over rather than through the chunk buffer.
            return try await body(pending.span, false)
        case .reader(var reader, var chunk):
            // The server delivers body and end as separate reads: a body part always has `nil` trailers
            // and carries the bytes, while the end read carries a non-nil `trailers` and an empty buffer.
            // Either way the buffer is swapped out here and read after the server call returns, so the
            // closure the server sees captures nothing but `Sendable` locals.
            var didEnd = false
            do {
                try await reader.read { buffer, trailers in
                    didEnd = trailers != nil
                    swap(&buffer, &chunk)
                }
            } catch {
                // Return the reader even on failure so a later drain/read doesn't see it lost, and
                // latch the failure: the stream's position is no longer known.
                self.stow(reader, chunk: chunk, finished: didEnd, failed: true)
                // The closure above cannot throw, so the server's `EitherError` has `Never` as its
                // second case: unwrap it. Cancellation stays itself, so callers can still recognise it;
                // anything else is the client's doing, and is wrapped so it reads as a bad request.
                switch error {
                case .first(let readFailure as CancellationError): throw readFailure
                case .first(let readFailure): throw RequestBodyTransportFailed(underlying: readFailure)
                }
            }
            let delivered = chunk.count
            let result: R
            do {
                result = try await body(chunk.span, didEnd)
            } catch {
                // A consumer that throws has not broken the stream, only stopped reading it, so the
                // bytes it was handed still count as consumed and the stream stays usable.
                self.stow(reader, chunk: chunk, finished: didEnd, consumed: delivered)
                throw error
            }
            self.stow(reader, chunk: chunk, finished: didEnd, consumed: delivered)
            return result
        }
    }

    /// Returns a checked-out reader and chunk buffer to the lock, latching the end if `finished`.
    ///
    /// The reader arrives `sending` — the call site proves it is region-disjoint, which holds because the
    /// server read's closure captured only `Sendable` state — and is boxed straight into a new `Mutex`,
    /// whose initialiser is the one entry point that accepts such a value. The box, being `Sendable`,
    /// can then be stored under the lock.
    private func stow(
        _ reader: consuming sending NIOHTTPServer.Reader,
        chunk: consuming UniqueArray<UInt8>,
        finished: Bool,
        failed: Bool = false,
        consumed: Int = 0
    ) {
        var box: Mutex<NIOHTTPServer.Reader?>? = Mutex(consume reader)
        var spare: UniqueArray<UInt8>? = consume chunk
        self.state.withLock { state in
            state.reader = box.take()
            spare?.removeAll(keepingCapacity: true)
            state.chunk = spare.take()
            if finished { state.finished = true }
            if failed { state.failed = true }
            state.consumed += consumed
        }
    }

    /// Body bytes handed to a consumer so far, for a caller that wants a size without collecting.
    package var bytesConsumed: Int {
        self.state.withLock { $0.consumed }
    }

    /// Whether a *transport* read has failed, after which the connection is being torn down.
    package var transportFailed: Bool {
        self.state.withLock { $0.failed }
    }

    /// Reads the whole body into one buffer, aborting with 413 if it exceeds `max`.
    ///
    /// `expecting` is the declared `Content-Length`, used only to size the buffer up front; it is
    /// clamped to `max` so an over-declaring client can't make us reserve more than we would accept.
    /// Reserving is worth doing: on a 16 MiB body it is the difference between ~1.7 ms and ~0.3 ms.
    func collect(max: Int, expecting declaredLength: Int? = nil) async throws -> Data {
        // Claim the whole stream before reading a byte of it. Somebody else having taken bytes means
        // what is left is not the whole body, and returning that would hand back a silently truncated
        // one — which is how a swallowed 413 upstream used to turn into a short body and a 200
        // downstream, and how two concurrent collects used to leave one of them with nothing.
        try self.state.withLock { state in
            if state.failed { throw RequestBodyReadFailed() }
            guard !state.collecting else { throw RequestBodyAlreadyBeingRead() }
            guard state.consumed == 0 else { throw RequestBodyPartiallyConsumed() }
            state.collecting = true
        }
        defer { self.state.withLock { $0.collecting = false } }
        var collected = Data()
        if let declaredLength {
            collected.reserveCapacity(min(declaredLength, max))
        }
        while true {
            let ended = try await self.read { span, isEnd -> Bool in
                // Take the bytes *before* checking the flag: a terminal read is allowed to carry a
                // final batch, and `AsyncReader`'s contract says the caller must process both.
                if !span.isEmpty {
                    // Check before appending so an over-limit chunk is never buffered. Subtracting
                    // (rather than adding) keeps the bound exact and can't overflow when `max` is `.max`.
                    guard span.count <= max - collected.count else {
                        throw Abort(.contentTooLarge, headers: .connectionClose)
                    }
                    span.withUnsafeBufferPointer { unsafe collected.append(contentsOf: $0) }
                }
                return isEnd
            }
            if ended {
                break
            }
        }
        return collected
    }

    /// Discards any unread body to its end, or stops once *this* drain has read more than `max` bytes.
    ///
    /// Draining to the end keeps the connection reusable; the bound is a DoS guard so an unconsumed
    /// body (e.g. a 404) can't force an unbounded read. Only bytes this drain reads count — not what
    /// the handler already consumed — so a large legitimate read that left a small tail still keeps
    /// keep-alive. Stopping short of `.end` makes the server close with `Connection: close`.
    func drain(max: Int) async throws {
        var drained = 0
        while true {
            let (ended, count) = try await self.read { span, isEnd in (isEnd, span.count) }
            // Count first: a terminal read may carry bytes, and they are part of what was drained.
            drained += count
            if ended {
                return
            }
            if drained > max {
                return
            }
        }
    }
}

/// Calls `body` with an empty span and `isEnd == true` — the end-of-body signal shared by every
/// read path, so the "empty span + ended" sentinel lives in exactly one place. An empty `Span` has
/// an immortal lifetime and owns nothing, so signalling the end allocates nothing.
private func signalEndOfBody<R>(to body: (Span<UInt8>, Bool) async throws -> R) async throws -> R {
    try await body(Span<UInt8>(), true)
}
