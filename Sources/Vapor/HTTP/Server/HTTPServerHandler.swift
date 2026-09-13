import NIOHTTPServer
import BasicContainers
public import HTTPTypes
import HTTPAPIs
import NIOCore
import NIOHTTP1
import NIOConcurrencyHelpers
import Synchronization
import Logging
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Bridges NIOHTTPServer's request handler protocol into Vapor's responder chain.
struct VaporHTTPServerHandler: HTTPServerRequestHandler {
    typealias RequestContext = NIOHTTPServer.RequestContext
    typealias Reader = NIOHTTPServer.Reader
    typealias ResponseSender = NIOHTTPServer.ResponseSender

    let context: ServerContext
    let responder: any Responder

    func handle(
        request: HTTPRequest,
        requestContext: consuming NIOHTTPServer.RequestContext,
        reader: consuming sending NIOHTTPServer.Reader,
        responseSender: consuming sending NIOHTTPServer.ResponseSender
    ) async throws {
        let bodyStream = RequestBodyStream(reader: consume reader)

        // 1. Drain any body the handler didn't read so the keep-alive connection stays usable. GET/HEAD
        // aren't expected to carry a body, so their budget is 0: a body-less request drains nothing
        // (just reads `.end`), and one that does carry a body is left unread, closing the connection.
        let drainLimit = (request.method == .get || request.method == .head)
            ? 0
            : context.configuration.value.maxDrainBytes

        defer { try? await bodyStream.drain(max: drainLimit) }

        // 2. Build Vapor request
        let peerCerts = try? await requestContext.peerCertificateChain
        let remoteAddress = requestContext.remoteAddress.flatMap { SocketAddress($0) }
        let localAddress = requestContext.localAddress.flatMap { SocketAddress($0) }

        // HTTPRequest.path is the raw request target, already percent-encoded,
        // and includes the query string (e.g. "/foo%20bar?baz=1").
        // Pass it as the sole argument so URI.init takes the path-only parsing
        // branch, which preserves percent encoding rather than double-encoding.
        let rawPath = request.path ?? "/"

        let requestID = request.headerFields[.xRequestId] ?? UUID().uuidString
        var responseSender = Optional(consume responseSender)
        do {
            try await withLogger(mergingMetadata: ["request-id": "\(requestID)"]) { _ in
                let vaporRequest = Request(
                    method: request.method,
                    url: URI(path: rawPath),
                    version: .init(major: 1, minor: 1),
                    headersNoUpdate: request.headerFields,
                    bodyStream: bodyStream,
                    remoteAddress: remoteAddress,
                    localAddress: localAddress,
                    peerCertificateChain: peerCerts,
                    requestID: requestID,
                    contentConfiguration: context.contentConfiguration,
                    defaultMaxBodySize: context.defaultMaxBodySize
                )

                // 3. Run responder chain
                let vaporResponse = try await responder.respond(to: vaporRequest)
                let httpResponse = HTTPResponse(
                    status: vaporResponse.status,
                    headerFields: vaporResponse.headers
                )

                // 4. Send the response head and body
                guard let sender = responseSender.take() else {
                    Logger.current.critical("Invalid server state - no response sender")
                    throw Abort(.internalServerError)
                }
                // Vapor currently doesn't have an API for informational responses, trying to return one would
                // result in a crash, so bypass that here
                guard vaporResponse.status.kind != .informational else {
                    Logger.current.error(
                        "Handler returned an informational status, which cannot be sent as a final response",
                        metadata: ["status": "\(vaporResponse.status.code)"])
                    var empty = UniqueArray<UInt8>()
                    try await sender.sendAndFinish(HTTPResponse(status: .internalServerError), buffer: &empty)
                    return
                }

                // If this is a HEAD request we don't need a body, so write an empty body out and don't
                // waste time going through the response body. `204` and `304` are defined as bodyless
                // too: writing one anyway breaks framing, and the client reads it as the start of the
                // next response.
                let bodyIsForbidden = request.method == .head
                    || vaporResponse.status == .noContent
                    || vaporResponse.status == .notModified
                guard !bodyIsForbidden else {
                    var empty = UniqueArray<UInt8>()
                    try await sender.sendAndFinish(httpResponse, buffer: &empty)
                    return
                }

                switch vaporResponse.body.storage {
                // A stream some copy of this body already collected is spent: its bytes live in the
                // body's shared cache, so it is serialised down the buffered path below instead of by
                // re-running a callback that would now write nothing.
                case .stream(let bodyStream) where bodyStream.state.collected == nil:
                    // Streaming body: send the head, then let the body closure write chunks straight
                    // into the server's writer. The writer is non-Sendable (it wraps the server's
                    // move-only response writer), so it stays in this task; each `write` awaits the
                    // transport, so backpressure propagates to the closure. The server appends the
                    // final chunk via `finish` once the closure returns.
                    let writer = NIOHTTPBodyWriterStorage(inner: try await sender.send(httpResponse))
                    let scope = HTTPBodyWriterScope()
                    do {
                        try await bodyStream.callback(NIOHTTPBodyWriter(writer, scope: scope))
                    } catch {
                        // Throwing out of the handler is how the server is told to abort: it closes the
                        // connection without a terminating chunk, so the client sees a truncated body.
                        // Finishing here would send one and present a partial body as a whole one.
                        writer.abandon()
                        throw error
                    }
                    if let declared = bodyStream.count, writer.bytesWritten != declared {
                        // The body did not match the length the head promised. Throw rather than return:
                        // a handler that returns with its response unfinished only has its connection torn
                        // down as inconsistent, whereas a thrown error drives the server's abort.
                        //
                        // Logged here as well as by the server, because the server's log line does not
                        // carry this request's ID.
                        Logger.current.debug(
                            "Response body stream wrote a different number of bytes than it declared, closing the connection",
                            metadata: [
                                "written": "\(writer.bytesWritten)",
                                "declared": "\(declared)",
                            ])
                        writer.abandon()
                        throw ResponseBodyLengthMismatch(declared: declared, written: writer.bytesWritten)
                    }
                    try await writer.finish(nil)
                default:
                    // Buffered body: single-shot write. Borrowing the body's bytes copies them straight
                    // into the server's container - a `.string`/`.data`/`.staticString` body is no
                    // longer materialised into an intermediate `ByteBuffer` first.
                    var responseBody = UniqueArray<UInt8>(minimumCapacity: vaporResponse.body.count ?? 0)
                    try await vaporResponse.body.withStreamingBytes { bytes in
                        responseBody.append(copying: bytes)
                    }
                    try await sender.sendAndFinish(httpResponse, buffer: &responseBody)
                }
            }
        } catch {
            // A throw out of here tells the server to abort the exchange, and for HTTP/1.1 that means writing
            // a response head if it believes none was written. Once the request body's transport has failed
            // the connection is already being torn down: NIO answered the parser error with its own 400,
            // below the server's keep-alive handler, and closed the channel. Nothing is left to abort, and
            // asking for one races NIO's deferred handler removal; if the abort lands first, the keep-alive
            // handler writes a second response head into a pipeline that already sent one, which NIO
            // asserts on. A cancelled task is in the same position. Return instead: the server logs an
            // unconcluded response and closes the connection, which is where it was going anyway.
            guard !bodyStream.transportFailed, !Task.isCancelled else {
                Logger.current.debug(
                    "Request ended without a response because its connection is gone",
                    metadata: ["request-id": "\(requestID)", "error": "\(error)"])
                return
            }
            throw error
        }
    }
}

/// A streaming response body that wrote a different number of bytes than it declared.
///
/// Thrown out of the request handler only to make the server abort the response. The server logs it
/// but never hands it on to a caller, so it carries nothing beyond what that log line needs.
struct ResponseBodyLengthMismatch: Error, CustomStringConvertible {
    let declared: Int
    let written: Int

    var description: String {
        "Response body stream declared \(self.declared) bytes but wrote \(self.written)"
    }
}

/// Holds the server's move-only response writer for the duration of one response.
///
/// The NIO writer is `~Copyable` and ``finish(_:)`` consumes it, so it lives in an `Optional`: a
/// class can't move a stored property out in place, and `Optional.take()` is how it is moved out.
/// This stays a class because the server mutates it across `await` points; the *lent* view handed
/// to user code is the non-escapable ``NIOHTTPBodyWriter`` below.
///
/// Needs no `Mutex` (unlike ``RequestBodyStream``): it lives only within the handler task and is never
/// stored in the `Sendable` `Response`, so it is never shared across isolation regions. Don't add a lock.
final class NIOHTTPBodyWriterStorage {
    private var inner: NIOHTTPServer.ResponseSender.Writer?

    /// Whether the response was deliberately left unfinished.
    ///
    /// Once the head is flushed it cannot be retracted, so a body that fails part-way is reported by
    /// *not* sending a terminating chunk: the client sees a truncated response rather than a
    /// well-formed short one. `NIOHTTPServer.ResponseSender.Writer` has no `fail` of its own — the
    /// supported way to abort is to throw out of the request handler, which makes the server close
    /// the connection without that chunk. So an abandoned writer is always about to be followed by a
    /// throw, but `deinit` cannot see a throw, which is why abandoning has to be recorded here to be
    /// told apart from simply forgetting to finish.
    private var wasAbandoned = false

    /// The number of body bytes written so far, used to check a stream against its declared length.
    private(set) var bytesWritten = 0

    init(inner: consuming NIOHTTPServer.ResponseSender.Writer) {
        self.inner = consume inner
    }

    /// Records that this response is being left unfinished on purpose, just before the handler
    /// throws to have the server abort it.
    func abandon() {
        self.wasAbandoned = true
    }

    func write(_ bytes: Span<UInt8>) async throws {
        // We need to copy here so the writer takes ownership of the data
        // TODO: This should be fixed in HTTP Server to avoid the copy
        var out = UniqueArray<UInt8>(minimumCapacity: bytes.count)
        out.append(copying: bytes)
        try await self.inner?.write(buffer: &out)
        self.bytesWritten += bytes.count
    }

    func write(_ bytes: some Sequence<UInt8>) async throws {
        var out = UniqueArray<UInt8>(minimumCapacity: bytes.underestimatedCount)
        // Staging is synchronous, so the sequence's own storage can be borrowed rather than copied
        // element by element; only the transport write is awaited, after the borrow has ended.
        let borrowed: Void? = bytes.withContiguousStorageIfAvailable { buffer in
            unsafe out.append(copying: buffer)
        }
        if borrowed == nil {
            out.append(copying: bytes)
        }
        // `write` drains `out`, so the count has to be taken first.
        let count = out.count
        try await self.inner?.write(buffer: &out)
        self.bytesWritten += count
    }

    func finish(_ trailingHeaders: HTTPFields?) async throws {
        guard let writer = self.inner.take() else { return }
        var empty = UniqueArray<UInt8>()
        try await writer.finish(buffer: &empty, finalElement: trailingHeaders)
    }

    deinit {
        // Finishing is async and cannot be done from here, so this only reports the mistake.
        // A writer released still holding the server's, without anyone having said the response was
        // being abandoned, is one that nobody finished. That surfaces later as `NIOAsyncWriter`'s
        // own `deinit` precondition, which names neither the response nor the layer responsible.
        // This is likely a race condition in here in HTTPServer - this should help us track it down
        assert(
            self.inner == nil || self.wasAbandoned,
            "Response body writer was released without being finished or abandoned. Every path out of a streaming response must call finish(_:) or abandon()."
        )
    }
}

/// Holds the server's move-only, non-`Sendable` request `Reader` behind a `Mutex`, so it can live in the
/// `Sendable` `Request` without `@unchecked`, `nonisolated(unsafe)` or `unsafe`.
///
/// `read` checks the reader out of the lock, awaits the server read *outside* it, and hands it back.
/// Two things make that hand-back safe without laundering:
///
/// 1. **The user's closure never enters the server read.** The chunk is moved *out* of the server's
///    read (its reusable buffer is swapped with a spare one that this stream keeps) and the user's
///    closure is called afterwards, on a `Span` of that chunk. Region isolation merges a value with
///    everything a call it takes part in can reach, so a closure that captured the user's closure (a
///    task-isolated parameter) would drag the reader into the task's region for good; a closure that
///    captures only `Sendable` state leaves it disconnected, and disconnected is what a `sending`
///    hand-back needs.
/// 2. **The reader re-enters the lock through `Mutex.init`, not through `withLock`.** Assigning a
///    non-`Sendable` value into `withLock`'s `inout sending` state is rejected for any value that a
///    closure captured, however it got there. `Mutex.init` takes its value `consuming sending` — that
///    parameter *is* the compiler-checked proof the value is region-disjoint — so the reader goes back
///    inside a freshly built inner `Mutex`, and it is that (`Sendable`) box that is stored. A `Mutex`
///    lives inline, so this costs no allocation.
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
                // second case: unwrap it and surface the transport error as itself.
                switch error {
                case .first(let readFailure): throw readFailure
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

extension HTTPFields {
    /// `Connection: close`, for the response to a request whose body we have decided not to finish
    /// reading — a 413, in practice.
    ///
    /// The rest of that body is still on the wire, and the drain that runs once the handler returns is
    /// bounded by `maxDrainBytes`: anything larger leaves the request unread, and the server then hangs
    /// up. The response head is long gone by that point, so the decision has to be made here, when the
    /// error is thrown. Without it the client is handed keep-alive framing and then cut off, and fails
    /// the upload it has already been answered rather than reading the answer.
    static let connectionClose: HTTPFields = {
        var fields = HTTPFields()
        fields.connection = .close
        return fields
    }()
}

/// Thrown by a read on a stream whose earlier read failed at the transport.
///
/// Once a transport read has failed the stream's position is unknown, so the alternative would be to
/// report a clean end-of-body on a body that was actually cut short.
public struct RequestBodyReadFailed: Error {}

extension RequestBodyReadFailed: AbortError {
    public var status: HTTPResponse.Status { .internalServerError }
    public var reason: String { "The request body stream failed and cannot be read again." }
}

/// Thrown by ``Request/Body/collect(max:)`` when something already took bytes off the stream.
///
/// A body is single-consumer, so what remains is not the whole body. Collecting it anyway would hand
/// back a silently truncated body — the failure mode this replaces.
public struct RequestBodyPartiallyConsumed: Error {}

extension RequestBodyPartiallyConsumed: AbortError {
    public var status: HTTPResponse.Status { .internalServerError }
    public var reason: String {
        "The request body was already partially read, so it can no longer be collected in full."
    }
}

/// Thrown when the request body is read from two tasks at once. It is a single-consumer stream, so this
/// is a programmer error, surfaced as a 500 rather than silently reporting an empty end-of-body.
public struct RequestBodyAlreadyBeingRead: Error {}

extension RequestBodyAlreadyBeingRead: AbortError {
    public var status: HTTPResponse.Status { .internalServerError }
    public var reason: String { "The request body is already being read by another task." }
}

/// Shared empty body, so the end-of-body signal doesn't allocate a `ByteBuffer` on every terminal read.
private let emptyRequestBody = ByteBuffer()

/// Calls `body` with an empty span and `isEnd == true` — the end-of-body signal shared by every
/// read path, so the "empty span + ended" sentinel lives in exactly one place.
private func signalEndOfBody<R>(to body: (Span<UInt8>, Bool) async throws -> R) async throws -> R {
    try await body(emptyRequestBody.readableBytesUInt8Span, true)
}

/// The server's concrete ``RequestBodyReader`` — a borrowed, non-escapable view onto the request body,
/// the mirror of ``NIOHTTPBodyWriter``. Lent only for a ``Request/Body/withReader(_:)`` closure;
/// being `~Escapable` it can't be stored, so "read the body twice" is a compile-time error. Each
/// ``read(_:)`` hands the next part out as a borrowed `Span<UInt8>`, copying nothing until user code keeps it.
struct NIORequestBodyReader: RequestBodyReader, ~Escapable {
    private let stream: RequestBodyStream

    @_lifetime(borrow scope)
    init(_ stream: RequestBodyStream, scope: borrowing RequestBodyReaderScope) {
        self.stream = stream
    }

    func read<R>(_ body: (Span<UInt8>, Bool) async throws -> R) async throws -> R {
        try await self.stream.read(body)
    }
}

/// Bridges Vapor's ``HTTPBodyWriter`` onto the server's move-only response writer.
///
/// Each chunk is copied into a `UniqueArray<UInt8>` and forwarded with `await`, so the transport's
/// backpressure (the socket/HTTP-2 flow-control window) propagates straight to the body-stream
/// closure — a fast producer suspends while a slow client catches up.
///
/// Non-escapable, so it cannot outlive the lend: this is what carries the server's move-only
/// guarantee through to user code. See https://github.com/vapor/vapor/issues/2976.
struct NIOHTTPBodyWriter: HTTPBodyWriter, ~Escapable {
    private let storage: NIOHTTPBodyWriterStorage

    @_lifetime(borrow scope)
    init(_ storage: NIOHTTPBodyWriterStorage, scope: borrowing HTTPBodyWriterScope) {
        self.storage = storage
    }

    func write(_ bytes: Span<UInt8>) async throws {
        try await self.storage.write(bytes)
    }

    func write(_ bytes: some Sequence<UInt8>) async throws {
        try await self.storage.write(bytes)
    }
}
