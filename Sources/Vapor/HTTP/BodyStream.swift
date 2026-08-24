#warning("Make this internal")
public import NIOCore

public enum BodyStreamResult: Sendable {
    /// A normal data chunk.
    /// There will be 0 or more of these.
    case buffer(ByteBuffer)
    /// Indicates an error.
    /// There will be 0 or 1 of these. 0 if the stream closes cleanly.
    case error(any Error)
    /// Indicates the stream has completed.
    /// There will be 0 or 1 of these. 0 if the stream errors.
    case end
}

extension BodyStreamResult: CustomStringConvertible {
    public var description: String {
        switch self {
        case .buffer(let buffer):
            return "buffer(\(buffer.readableBytes) bytes)"
        case .error(let error):
            return "error(\(error))"
        case .end:
            return "end"
        }
    }
}

extension BodyStreamResult: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .buffer(let buffer):
            let value = String(decoding: buffer.readableBytesView, as: UTF8.self)
            return "buffer(\(value))"
        case .error(let error):
            return "error(\(error))"
        case .end:
            return "end"
        }
    }
}

/// A type that represents the writable handle of a streamed ``Response`` body
public protocol BodyStreamWriter: Sendable {
    /// Writes an event to a streaming HTTP body. If the `result` is `.end` or `.error`, the stream ends.
    func write(_ result: BodyStreamResult) async throws

    /// Writes a `ByteBuffer` to the stream. Provides a default implementation that calls itself using `BodyStreamResult`
    func writeBuffer(_ buffer: ByteBuffer) async throws
}

extension BodyStreamWriter {
    /// Writes the buffer wrapped in a ``BodyStreamResult`` to `self`
    public func writeBuffer(_ buffer: ByteBuffer) async throws {
        try await write(.buffer(buffer))
    }
}
