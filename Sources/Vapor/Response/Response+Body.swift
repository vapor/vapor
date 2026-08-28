#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif
import HTTPTypes
import Synchronization

extension Response {
    /// Shared consumption state for a streaming body, this ensures it's only called once and can be shared amongst copies
    final class BodyStreamState: Sendable {
        private let cache = Mutex<Data?>(nil)

        /// The bytes this stream produced, or `nil` if it has not been collected yet.
        var collected: Data? {
            self.cache.withLock { $0 }
        }

        func store(_ data: Data) {
            self.cache.withLock { $0 = data }
        }
    }

    struct BodyStream: Sendable {
        let count: Int
        let callback: @Sendable (any ResponseBodyWriter) async throws -> ()
        let state = BodyStreamState()
    }

    /// Represents a `Response`'s body.
    ///
    ///     let body = Response.Body(string: "Hello, world!")
    ///
    /// This can contain any data (streaming or static) and should match the message's `"Content-Type"` header.
    public struct Body: CustomStringConvertible, ExpressibleByStringLiteral, Sendable {
        /// The internal HTTP body storage enum. This is an implementation detail.
        internal enum Storage: Sendable {
            /// Cases
            case none
            case data(Data)
            case staticString(StaticString)
            case string(String)
            case stream(BodyStream)
        }

        /// An empty `Response.Body`.
        public static let empty: Body = .init()

        /// Read the body's bytes incrementally, without buffering the whole thing.
        ///
        /// The closure is called once per chunk, in order, and is backpressured: a streaming body
        /// only produces the next chunk once the closure returns. Each span is only valid for the
        /// duration of that call - `RawSpan` is non-escapable, so the compiler enforces that: the
        /// closure cannot stash a span and read it later.
        ///
        /// Works for every kind of body - a buffered one is handed over as a single chunk, and an
        /// empty one calls the closure not at all - so callers do not need to branch on storage.
        ///
        /// Note this *consumes* a streaming body: it runs the stream's callback,
        /// so it has that closure's side effects and must not be called twice on the same body.
        /// A streaming body can also throw part-way, after the closure has already seen chunks.
        ///
        /// Use ``collect()`` instead when the whole body is genuinely needed in memory.
        public func withStreamingBytes(_ body: @escaping (RawSpan) async throws -> Void) async throws {
            switch self.storage {
            case .stream(let stream):
                // See if we're already collection so we don't run again
                if let collected = stream.state.collected {
                    try await body(collected.span.bytes)
                } else {
                    try await stream.callback(ForwardingBodyWriter(body))
                }
            case .none:
                return
            case .data(let data):
                try await body(data.span.bytes)
            case .string(let string):
                try await body(string.utf8Span.span.bytes)
            case .staticString(let staticString):
                try await unsafe body(
                    RawSpan(_unsafeStart: staticString.utf8Start, byteCount: staticString.utf8CodeUnitCount)
                )
            }
        }

        /// Fold the body's bytes into a value, one chunk at a time.
        ///
        /// The streaming counterpart to computing something over a whole body without ever holding
        /// it in memory - hashing, counting, checksumming, incremental parsing. Chunk delivery and
        /// backpressure are exactly ``withStreamingBytes(_:)``'s, so a streaming body is folded as
        /// it arrives and a buffered one is folded in a single step.
        ///
        ///     let digest = try await body.reduceBytes(into: SHA256()) { hasher, span in
        ///         span.withUnsafeBytes { hasher.update(bufferPointer: $0) }
        ///     }.finalize()
        ///
        /// Like ``withStreamingBytes(_:)`` this consumes a streaming body.
        ///
        /// - Parameters:
        ///   - initialResult: The value to start from.
        ///   - updateAccumulatingResult: Folds each chunk into the accumulator.
        /// - Returns: The accumulated value. An empty body returns `initialResult` untouched.
        public func reduceBytes<R>(
            into initialResult: R,
            _ updateAccumulatingResult: @escaping (inout R, RawSpan) async throws -> Void
        ) async throws -> R {
            // `inout` can't cross into an escaping closure, so the accumulator is boxed for the
            // duration. That is an implementation detail: callers still write plain `inout`.
            let accumulator = ReduceBox(initialResult)
            try await self.withStreamingBytes { span in
                try await updateAccumulatingResult(&accumulator.value, span)
            }
            return accumulator.value
        }

        /// The body decoded as UTF-8, or `nil` if it is empty or is a stream nothing has collected.
        ///
        /// Use ``string(max:)`` to collect the body and always return a string
        public var string: String? {
            switch self.storage {
            case .data(let data): return String(decoding: data, as: UTF8.self)
            case .staticString(let staticString): return staticString.description
            case .string(let string): return string
            case .none: return nil
            case .stream(let stream): return stream.state.collected.map { String(decoding: $0, as: UTF8.self) }
            }
        }

        /// The size of the HTTP body's data.
        /// `-1` is a chunked stream whose length is unknown. If the stream has already been collected,
        /// then the correct length will be reported - including when another copy of the body collected
        /// it. Collect one with ``collect(max:)``, ``data(max:)`` or ``string(max:)``.
        public var count: Int {
            switch self.storage {
            case .data(let data): return data.count
            case .staticString(let staticString): return staticString.utf8CodeUnitCount
            case .string(let string): return string.utf8.count
            case .none: return 0
            case .stream(let stream): return stream.state.collected?.count ?? stream.count
            }
        }

        /// The body's bytes, or `nil` if it is empty or is a stream nothing has collected.
        ///
        /// Use ``data(max:)`` to collect the body and always return ``Foundation/Data``
        public var data: Data? {
            switch self.storage {
            case .data(let data): return data
            case .staticString(let staticString): return unsafe Data(bytes: staticString.utf8Start, count: staticString.utf8CodeUnitCount)
            case .string(let string): return Data(string.utf8)
            case .none: return nil
            case .stream(let stream): return stream.state.collected
            }
        }

        /// The body's bytes, collecting a streaming body first if nothing has collected it yet.
        ///
        /// The collecting counterpart to ``data``, for where the body may or may not be a stream and
        /// the bytes are genuinely needed - a client response, say. An already-collected or buffered
        /// body is returned without re-reading anything.
        /// 
        /// - Parameter max: The most bytes to buffer, as ``collect(max:)``. `nil` buffers whatever
        ///   the body produces.
        /// - Returns: The body's bytes, or `nil` if the body is empty.
        /// - Throws: ``Abort`` with `.contentTooLarge` if a streaming body exceeds `max`.
        public func data(max: Int? = nil) async throws -> Data? {
            // Collecting through a copy: `collect(max:)` is `mutating`, but the bytes it produces
            // land in the stream's shared state, so the caller's body sees them regardless.
            var body = self
            return try await body.collect(max: max)
        }

        /// The body decoded as UTF-8, collecting a streaming body first if nothing has collected it yet.
        ///
        /// The collecting counterpart to ``string``. See ``data(max:)`` for the semantics; this
        /// decodes the result, substituting U+FFFD for any invalid UTF-8 rather than failing.
        ///
        /// - Parameter max: The most bytes to buffer, as ``collect(max:)``. `nil` buffers whatever
        ///   the body produces.
        /// - Returns: The body decoded as UTF-8, or `nil` if the body is empty.
        /// - Throws: ``Abort`` with `.contentTooLarge` if a streaming body exceeds `max`.
        public func string(max: Int? = nil) async throws -> String? {
            try await self.data(max: max).map { String(decoding: $0, as: UTF8.self) }
        }

        /// Reads the whole body into memory, running a streaming body to completion.
        ///
        /// Collecting a streaming body **replaces** it with the bytes it produced as a mutating operation. A stream's
        /// closure can only be relied on to run once - it may be reading a file handle, or draining
        /// an `AsyncSequence` - so re-running it silently yields a short or empty body. Caching the
        /// result means anything further down the chain, including the server that serialises the
        /// response, sees an ordinary in-memory body instead.
        ///
        /// The bytes are also cached in state shared with every *copy* of this body, so collecting
        /// through one copy is visible from the others. That matters where the collection cannot be
        /// written back - a `ContentContainer` reached through a computed `content` property holds a
        /// copy, so without the shared cache decoding a streaming body would drain it and leave the
        /// original pointing at a spent stream.
        ///
        /// Use ``withStreamingBytes(_:)`` instead when the whole body is not genuinely needed in memory.
        ///
        /// - Parameter max: The most bytes to buffer. A stream that produces more fails with
        ///   ``Abort`` `.contentTooLarge` rather than growing without bound - a body arriving from
        ///   somewhere else, such as a client response, is not bounded by anything this process
        ///   controls. `nil`, the default, buffers whatever the body produces.
        /// - Returns: The body's bytes, or `nil` if the body is empty.
        /// - Throws: ``Abort`` with `.contentTooLarge` if a streaming body exceeds `max`.
        public mutating func collect(max: Int? = nil) async throws -> Data? {
            switch self.storage {
            case .stream(let stream):
                if let collected = stream.state.collected {
                    self.storage = .data(collected)
                    return collected
                }
                if let max, stream.count > max {
                    throw Abort(.contentTooLarge)
                }
                let initialCapacity = stream.count >= 0 ? stream.count : 0
                let writer = CollectingBodyWriter(capacity: initialCapacity, max: max)
                try await stream.callback(writer)
                stream.state.store(writer.data)
                self.storage = .data(writer.data)
                return writer.data
            default:
                return self.data
            }
        }

        // See `CustomStringConvertible.description`.
        public var description: String {
            switch storage {
            case .none: return "<no body>"
            case .data(let data): return String(decoding: data, as: UTF8.self)
            case .staticString(let string): return string.description
            case .string(let string): return string
            case .stream: return "<stream>"
            }
        }

        internal var storage: Storage

        /// Creates an empty body. Useful for `GET` requests where HTTP bodies are forbidden.
        public init() {
            self.storage = .none
        }

        /// Create a new body wrapping `Data`.
        public init(data: Data) {
            storage = .data(data)
        }

        /// Create a new body from the UTF8 representation of a `StaticString`.
        public init(staticString: StaticString) {
            storage = .staticString(staticString)
        }

        /// Create a new body from the UTF8 representation of a `String`.
        public init(string: String) {
            self.storage = .string(string)
        }

        /// Creates a chunked, streaming HTTP ``Response`` body.
        ///
        /// The closure receives a ``ResponseBodyWriter`` and writes chunks to it with `await`. Writes are
        /// backpressured by the transport, so the closure naturally throttles to the speed of the client.
        /// Throwing from the closure fails the response.
        ///
        /// - Parameters:
        ///   - stream: The closure that writes the body chunks.
        ///   - count: The number of bytes that will be written. The `stream` **MUST** produce exactly `count` bytes.
        public init(stream: @escaping @Sendable (any ResponseBodyWriter) async throws -> (), count: Int) {
            self.storage = .stream(.init(count: count, callback: stream))
        }

        /// Creates a chunked, streaming HTTP ``Response`` body of unknown length.
        ///
        /// See ``init(stream:count:)`` for the streaming semantics.
        ///
        /// - Parameters:
        ///   - stream: The closure that writes the body chunks.
        public init(stream: @escaping @Sendable (any ResponseBodyWriter) async throws -> ()) {
            self.init(stream: stream, count: -1)
        }

        /// `ExpressibleByStringLiteral` conformance.
        public init(stringLiteral value: String) {
            self.storage = .string(value)
        }

        /// Internal init.
        internal init(storage: Storage) {
            self.storage = storage
        }
    }
}

/// Holds a ``Response/Body/reduceBytes(into:_:)`` accumulator so it can be mutated from inside an
/// escaping closure. Not locked: the chunk closure is driven serially by the body itself, never
/// concurrently.
private final class ReduceBox<R> {
    var value: R
    init(_ value: R) { self.value = value }
}

/// A ``ResponseBodyWriter`` that forwards each chunk straight to a closure, used to drive a
/// streaming body incrementally instead of collecting it.
private final class ForwardingBodyWriter: ResponseBodyWriter {
    let onChunk: (RawSpan) async throws -> Void

    init(_ onChunk: @escaping (RawSpan) async throws -> Void) {
        self.onChunk = onChunk
    }

    func write(_ bytes: RawSpan) async throws {
        try await self.onChunk(bytes)
    }
}

/// A ``ResponseBodyWriter`` that accumulates everything written into `Data`, used to
/// eagerly collect a streaming body instead of forwarding it to the connection.
private final class CollectingBodyWriter: ResponseBodyWriter {
    var data: Data
    let max: Int?

    init(capacity: Int, max: Int?) {
        self.data = Data(capacity: capacity)
        self.max = max
    }

    func write(_ bytes: RawSpan) async throws {
        try self.checkLimit(adding: bytes.byteCount)
        bytes.withUnsafeBytes { self.data.append(contentsOf: $0) }
    }

    /// Appending is synchronous, so the sequence's own storage can be borrowed instead of copying
    /// it into a `ContiguousArray` first, as the protocol's default implementation must.
    func write(_ bytes: some Sequence<UInt8>) async throws {
        self.data.append(contentsOf: bytes)
        try self.checkLimit(adding: 0)
    }

    private func checkLimit(adding count: Int) throws {
        guard let max else { return }
        guard self.data.count + count <= max else {
            throw Abort(.contentTooLarge)
        }
    }
}
