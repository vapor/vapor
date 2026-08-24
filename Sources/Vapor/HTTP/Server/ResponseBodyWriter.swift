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
/// The protocol is class-bound because concrete writers wrap the server's move-only response
/// writer, which they mutate in place across `await` points as chunks are written.
public protocol ResponseBodyWriter: AnyObject {
    /// Write a single ByteBuffer.
    func write(_ buffer: ByteBuffer) async throws
    /// Write a sequence of ByteBuffers.
    func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws
    /// Finish writing the body with optional trailing headers.
    func finish(_ trailingHeaders: HTTPFields?) async throws
}

extension ResponseBodyWriter {
    @inlinable
    public func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws {
        for buffer in buffers {
            try await self.write(buffer)
        }
    }
}
