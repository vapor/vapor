import NIOCore
import HTTPTypes

/// Protocol for writing HTTP response bodies.
///
/// Implementations of this protocol are provided by the HTTP server layer
/// and allow Vapor's response body types to write their data to the underlying connection.
public protocol ResponseBodyWriter {
    /// Write a single ByteBuffer.
    mutating func write(_ buffer: ByteBuffer) async throws
    /// Write a sequence of ByteBuffers.
    mutating func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws
    /// Finish writing the body with optional trailing headers.
    consuming func finish(_ trailingHeaders: HTTPFields?) async throws
}

extension ResponseBodyWriter {
    @inlinable
    public mutating func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws {
        for buffer in buffers {
            try await self.write(buffer)
        }
    }
}
