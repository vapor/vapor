#warning("Make this internal")
public import NIOCore
public import HTTPTypes

/// Protocol for writing HTTP response bodies.
///
/// Implementations of this protocol are provided by the HTTP server layer and allow Vapor's
/// response body types to write their data straight to the underlying connection. Writes are
/// backpressured: `write` suspends while the transport can't accept more data, so a streaming
/// body naturally throttles to the speed of the client.
///
/// The protocol is `~Copyable` because concrete writers wrap the server's move-only response
/// writer; the body-stream closure receives one as ``ResponseBodyStreamWriter``.
public protocol ResponseBodyWriter: ~Copyable {
    /// Write a single ByteBuffer.
    mutating func write(_ buffer: ByteBuffer) async throws
    /// Write a sequence of ByteBuffers.
    mutating func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws
    /// Finish writing the body with optional trailing headers.
    mutating func finish(_ trailingHeaders: HTTPFields?) async throws
}

extension ResponseBodyWriter where Self: ~Copyable {
    @inlinable
    public mutating func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws {
        for buffer in buffers {
            try await self.write(buffer)
        }
    }
}

/// The writer handed to a streaming ``Response/Body`` closure.
///
/// This is the move-only existential of ``ResponseBodyWriter``. The `& ~Copyable` suppression is
/// required because the concrete writer wraps the server's move-only response writer; a bare
/// `any ResponseBodyWriter` would only box `Copyable` conformers.
public typealias ResponseBodyStreamWriter = any ResponseBodyWriter & ~Copyable
