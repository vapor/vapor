/// Protocol for writing HTTP response bodies.
///
/// Implementations of this protocol are provided by the HTTP server layer and allow Vapor's
/// response body types to write their data straight to the underlying connection. Writes are
/// backpressured: `write` suspends while the transport can't accept more data, so a streaming
/// body naturally throttles to the speed of the client.
///
/// The protocol is class-bound because concrete writers wrap the server's move-only response
/// writer, which they mutate in place across `await` points as chunks are written. Only `write`
/// is exposed: concluding the response is the server's responsibility, so a body-stream closure
/// can never end the stream itself.
public protocol ResponseBodyWriter: AnyObject {
    /// Write a single chunk of bytes
    func write(_ bytes: RawSpan) async throws

    /// Write a sequence of bytes.
    /// This is required on the protocol to ensure it gets used when ``ResponseBodyWriter`` is an existential.
    /// This allows us to avoid a copy in certain scenarios
    func write(_ bytes: some Sequence<UInt8>) async throws
}

extension ResponseBodyWriter {
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
