/// Anchors a ``ResponseBodyWriter``'s lifetime to the scope that lends it out.
///
/// A writer is non-escapable, and its lifetime is expressed as a dependency on a borrow of one of
/// these. Whoever drives a body stream creates a token as a local, lends it to the writer it builds,
/// and lets it die when the call returns — at which point the compiler considers every writer
/// derived from it dead too.
struct ResponseBodyWriterScope: ~Copyable {
    init() {}
}

/// Protocol for writing HTTP response bodies.
///
/// Implementations of this protocol are provided by the HTTP server layer and allow Vapor's
/// response body types to write their data straight to the underlying connection. Writes are
/// backpressured: `write` suspends while the transport can't accept more data, so a streaming
/// body naturally throttles to the speed of the client.
///
/// Only `write` is exposed: concluding the response is the server's responsibility, so a
/// body-stream closure can never end the stream itself.
///
/// A writer is **non-escapable**, and is only valid for the duration of the body-stream closure it
/// was handed to. This ensures a write can never happen after the response was concluded
/// See https://github.com/vapor/vapor/issues/2976.
public protocol ResponseBodyWriter: ~Escapable {
    /// Write a single chunk of bytes
    func write(_ bytes: RawSpan) async throws

    /// Write a sequence of bytes.
    /// This is required on the protocol to ensure it gets used when ``ResponseBodyWriter`` is an existential.
    /// This allows us to avoid a copy in certain scenarios
    func write(_ bytes: some Sequence<UInt8>) async throws
}

extension ResponseBodyWriter where Self: ~Escapable {
    /// Write a single chunk of bytes
    @inlinable
    public func write(_ bytes: Span<UInt8>) async throws {
        try await self.write(bytes.bytes)
    }

    /// Write the UTF-8 Representation of a `String`
    @inlinable
    public func write(_ string: String) async throws {
        try await self.write(string.utf8Span.span.bytes)
    }

    /// Write a sequence of bytes.
    ///
    /// Copies into contiguous storage so the bytes can be handed over as a `RawSpan`.
    /// `withContiguousStorageIfAvailable` is unusable here: its closure is synchronous, and
    /// `write(_ bytes: RawSpan)` must be awaited. Writers that copy synchronously should override.
    @inlinable
    public func write(_ bytes: some Sequence<UInt8>) async throws {
        let contiguous = ContiguousArray(bytes)
        try await self.write(contiguous.span.bytes)
    }

    /// Write a sequence of byte chunks, in order
    /// This will copy the bytes into contiguous storage first. Use the `Span` APIs to avoid copies
    @inlinable
    public func write(contentsOf chunks: some Sequence<some Sequence<UInt8>>) async throws {
        for chunk in chunks {
            try await self.write(chunk)
        }
    }
}
