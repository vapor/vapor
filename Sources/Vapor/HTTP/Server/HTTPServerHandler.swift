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
                let writer = NIOResponseBodyWriterStorage(inner: try await sender.send(httpResponse))
                let scope = ResponseBodyWriterScope()
                try await bodyStream.callback(NIOResponseBodyWriter(writer, scope: scope))
                guard bodyStream.count == nil || writer.bytesWritten == bodyStream.count else {
                    // Stream length differs from what was declared: an error state, so close the connection
                    Logger.current.debug(
                        "Response body stream wrote a different number of bytes than it declared, closing the connection",
                        metadata: [
                            "written": "\(writer.bytesWritten)",
                            "declared": "\(bodyStream.count.map(String.init) ?? "unknown")",
                        ])
                    return
                }
                try await writer.finish(nil)
            default:
                // Buffered body: single-shot write. Borrowing the body's bytes copies them straight
                // into the server's container - a `.string`/`.data`/`.staticString` body is no
                // longer materialised into an intermediate `ByteBuffer` first.
                var responseBody = UniqueArray<UInt8>(minimumCapacity: vaporResponse.body.count ?? 0)
                try await vaporResponse.body.withStreamingBytes { bytes in
                    bytes.withUnsafeBytes { unsafe responseBody.append(copying: $0) }
                }
                try await sender.sendAndFinish(httpResponse, buffer: &responseBody)
            }
        }
    }
}

/// Holds the server's move-only response writer for the duration of one response.
///
/// The NIO writer is `~Copyable` and ``finish(_:)`` consumes it, so it lives in an `Optional`: a
/// class can't move a stored property out in place, and `Optional.take()` is how it is moved out.
/// This stays a class because the server mutates it across `await` points; the *lent* view handed
/// to user code is the non-escapable ``NIOResponseBodyWriter`` below.
///
/// Needs no `Mutex` (unlike ``RequestBodyStream``): it lives only within the handler task and is never
/// stored in the `Sendable` `Response`, so it is never shared across isolation regions. Don't add a lock.
final class NIOResponseBodyWriterStorage {
    private var inner: NIOHTTPServer.ResponseSender.Writer?

    /// The number of body bytes written so far, used to check a stream against its declared length.
    private(set) var bytesWritten = 0

    init(inner: consuming NIOHTTPServer.ResponseSender.Writer) {
        self.inner = consume inner
    }

    func write(_ bytes: RawSpan) async throws {
        // We need to copy here so the writer takes ownership of the data
        // TODO: This should be fixed in HTTP Server to avoid the copy
        var out = UniqueArray<UInt8>(minimumCapacity: bytes.byteCount)
        bytes.withUnsafeBytes { unsafe out.append(copying: $0) }
        try await self.inner?.write(buffer: &out)
        self.bytesWritten += bytes.byteCount
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
}

/// A `Sendable` box that ferries a non-`Sendable`, `~Copyable` value across isolation regions.
///
/// The value is only ever moved in and out, never shared. `init` takes `consuming sending` (the caller
/// proves it is region-disjoint) and `take()` hands it back out as `sending`; the `nonisolated(unsafe)`
/// storage is just the parking spot in between.
private struct Disconnected<Value: ~Copyable>: ~Copyable, Sendable {
    private nonisolated(unsafe) var value: Value?

    init(_ value: consuming sending Value) {
        unsafe self.value = .some(value)
    }

    /// Moves the value out, leaving the box empty (`nil` if already taken).
    mutating func take() -> sending Value? {
        nonisolated(unsafe) let taken = unsafe self.value.take()
        return unsafe taken
    }

    /// Puts a value back into the box.
    mutating func put(_ newValue: consuming sending Value) {
        unsafe self.value = .some(newValue)
    }
}

/// Holds the server's move-only, non-`Sendable` request `Reader` behind a `Mutex`, so it can live in the
/// `Sendable` `Request` without `@unchecked`. `read` checks the reader out, awaits the part *outside* the
/// lock, then hands it back — the lock only guards the synchronous hand-off. A body is single-consumer: a
/// read that finds the reader already checked out throws ``RequestBodyAlreadyBeingRead`` rather than
/// silently reporting end-of-body.
package final class RequestBodyStream: Sendable {
    /// The reader plus its end latch. `~Copyable` because the `Reader` is move-only.
    private struct State: ~Copyable {
        var reader: Disconnected<NIOHTTPServer.Reader>
        var finished = false
    }
    private let state: Mutex<State>

    /// The result of checking the reader out of the lock: ours to read, already ended, or held by
    /// another task. `~Copyable` because it may carry the move-only `Reader`.
    private enum Checkout: ~Copyable {
        /// The reader is ours for this read.
        case reader(NIOHTTPServer.Reader)
        /// The body already ended; signal end-of-body.
        case ended
        /// Another task holds the reader (single-consumer contract violated).
        case busy
    }

    init(reader: consuming sending NIOHTTPServer.Reader) {
        self.state = Mutex(State(reader: Disconnected(consume reader)))
    }

    /// Reads one part of the body, handing its bytes to `body` as a borrowed ``RawSpan`` plus a flag
    /// that is `true` at end-of-body (the span is then empty). The single primitive behind
    /// ``collect(max:)``, ``drain(max:)`` and ``RequestBodyReader``. The span borrows the server's
    /// reusable buffer, so it is valid only for the call — copy out what you keep.
    func read<R>(_ body: (RawSpan, Bool) async throws -> R) async throws -> R {
        // Check the reader out of the lock (synchronously); the `await` below happens outside it.
        let checkout = self.state.withLock { state -> sending Checkout in
            if state.finished { return .ended }
            if let reader = state.reader.take() { return .reader(reader) }
            // Not finished, yet the reader is gone: another task is mid-read.
            return .busy
        }
        switch consume checkout {
        case .ended:
            return try await signalEndOfBody(to: body)
        case .busy:
            throw RequestBodyAlreadyBeingRead()
        case .reader(var reader):
            // The server delivers body and end as separate reads: a body part always has `nil` trailers
            // and carries the bytes, while the end read carries a non-nil `trailers` and an empty buffer.
            var didEnd = false
            do {
                let result = try await reader.read { chunk, trailers in
                    guard trailers == nil else {
                        didEnd = true
                        return try await signalEndOfBody(to: body)
                    }
                    return try await body(chunk.span.bytes, false)
                }
                self.stow(consume reader, finished: didEnd)
                return result
            } catch {
                // Return the reader even on failure so a later drain/read doesn't see it lost, and
                // still latch the end if the body had already finished before the error.
                self.stow(consume reader, finished: didEnd)
                throw error
            }
        }
    }

    /// Returns a checked-out reader to the lock, latching the end if `finished`.
    ///
    /// After `reader.read` the reader is task-isolated (its closure captured the body), so it is laundered
    /// into a region-disjoint value here — the one place that establishes it — before re-entering the box.
    private func stow(_ reader: consuming NIOHTTPServer.Reader, finished: Bool) {
        nonisolated(unsafe) let laundered = consume reader
        var box = Disconnected(laundered)
        self.state.withLock { state in
            if let reader = box.take() { state.reader.put(reader) } // just-created box always binds
            if finished { state.finished = true }
        }
    }

    /// Reads the whole body into one buffer, aborting with 413 if it exceeds `max`.
    func collect(max: Int) async throws -> ByteBuffer {
        var collected = ByteBuffer()
        while true {
            let ended = try await self.read { span, isEnd -> Bool in
                if isEnd {
                    return true
                }
                // Check before appending so an over-limit chunk is never buffered. Subtracting
                // (rather than adding) keeps the bound exact and can't overflow when `max` is `.max`.
                guard span.byteCount <= max - collected.readableBytes else {
                    throw Abort(.contentTooLarge)
                }
                _ = span.withUnsafeBytes { unsafe collected.writeBytes($0) }
                return false
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
            let (ended, count) = try await self.read { span, isEnd in (isEnd, span.byteCount) }
            if ended {
                return
            }
            drained += count
            if drained > max {
                return
            }
        }
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
private func signalEndOfBody<R>(to body: (RawSpan, Bool) async throws -> R) async throws -> R {
    try await body(emptyRequestBody.readableBytesSpan, true)
}

/// Holds an already-buffered body until ``NIORequestBodyReader`` replays it, then latches to `nil` so a
/// second read reports end-of-body. A reference type so `read` can stay non-mutating (`borrowing`): the
/// "already replayed" state lives behind the reference, not in the borrowed reader.
final class CollectedBodyReplay {
    var buffer: ByteBuffer?
    init(_ buffer: ByteBuffer?) {
        self.buffer = buffer
    }
}

/// The server's concrete ``RequestBodyReader`` — a borrowed, non-escapable view onto the request body,
/// the mirror of ``NIOResponseBodyWriter``. Lent only for a ``Request/Body/withReader(_:)`` closure;
/// being `~Escapable` it can't be stored, so "read the body twice" is a compile-time error. Each
/// ``read(_:)`` hands the next part out as a borrowed ``RawSpan``, copying nothing until user code keeps it.
struct NIORequestBodyReader: RequestBodyReader, ~Escapable {
    /// Either the live server stream, or an already-buffered body replayed as a single chunk.
    enum Source {
        case stream(RequestBodyStream)
        case collected(CollectedBodyReplay)
    }
    private let source: Source

    @_lifetime(borrow scope)
    init(_ source: consuming Source, scope: borrowing RequestBodyReaderScope) {
        self.source = source
    }

    func read<R>(_ body: (RawSpan, Bool) async throws -> R) async throws -> R {
        switch self.source {
        case .stream(let stream):
            return try await stream.read(body)
        case .collected(let replay):
            guard let buffer = replay.buffer, buffer.readableBytes > 0 else {
                // Nothing to replay (already spent, or a buffered-but-empty body): signal end with no
                // chunk, so an empty body delivers zero chunks whether it was pre-collected, a raw
                // `.stream`, or `.none` — matching `Response.Body.withStreamingBytes`.
                replay.buffer = nil
                return try await signalEndOfBody(to: body)
            }
            // A pre-buffered body is replayed as one chunk, then ends on the next read. The buffer
            // owns its bytes and is held for the duration of the call, so its span is handed over
            // directly rather than copied into a fresh buffer.
            replay.buffer = nil
            return try await body(buffer.readableBytesSpan, false)
        }
    }
}

/// Bridges Vapor's ``ResponseBodyWriter`` onto the server's move-only response writer.
///
/// Each chunk is copied into a `UniqueArray<UInt8>` and forwarded with `await`, so the transport's
/// backpressure (the socket/HTTP-2 flow-control window) propagates straight to the body-stream
/// closure — a fast producer suspends while a slow client catches up.
///
/// Non-escapable, so it cannot outlive the lend: this is what carries the server's move-only
/// guarantee through to user code. See https://github.com/vapor/vapor/issues/2976.
struct NIOResponseBodyWriter: ResponseBodyWriter, ~Escapable {
    private let storage: NIOResponseBodyWriterStorage

    @_lifetime(borrow scope)
    init(_ storage: NIOResponseBodyWriterStorage, scope: borrowing ResponseBodyWriterScope) {
        self.storage = storage
    }

    func write(_ bytes: RawSpan) async throws {
        try await self.storage.write(bytes)
    }

    func write(_ bytes: some Sequence<UInt8>) async throws {
        try await self.storage.write(bytes)
    }
}
