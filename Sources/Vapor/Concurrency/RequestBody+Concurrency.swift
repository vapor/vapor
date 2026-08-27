#warning("Make this internal")
public import NIOCore
import NIOConcurrencyHelpers

// MARK: - Request.Body.AsyncSequence
extension Request.Body: AsyncSequence {
    public typealias Element = ByteBuffer

    /// This wrapper generalizes our implementation.
    /// `RequestBody.AsyncIterator` is the override point for
    /// using another implementation
    public struct AsyncIterator: AsyncIteratorProtocol {
        // Iterate the live stream, or hand back an already-buffered body as a single element.
        enum Source {
            case stream(RequestBodyStream.AsyncIterator)
            case collected(ByteBuffer?)
        }
        var source: Source

        public mutating func next() async throws -> ByteBuffer? {
            switch source {
            case .stream(var iter):
                let chunk = try await iter.next()
                self.source = .stream(iter)
                return chunk
            case .collected(let buffer):
                self.source = .collected(nil)
                return buffer
            }
        }
    }

    /// Generates an `AsyncIterator` to stream the body’s content as
    /// `ByteBuffer` sequences. This implementation supports backpressure using
    /// `NIOAsyncSequenceProducerBackPressureStrategies`
    /// - Returns: `AsyncIterator` containing the `Request.Body` as a
    /// `ByteBuffer` sequence
    public func makeAsyncIterator() -> AsyncIterator {
        switch self.request.bodyStorage.withLockedValue({ $0 }) {
        case .stream(let stream):
            return AsyncIterator(source: .stream(stream.makeAsyncIterator()))
        case .collected(let buffer):
            return AsyncIterator(source: .collected(buffer))
        case .none:
            return AsyncIterator(source: .collected(nil))
        }
    }
}
