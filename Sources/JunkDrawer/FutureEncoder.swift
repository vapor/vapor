import Async

/// Capable of encoding futures.
public protocol FutureEncoder: class {
    /// Encodes a future to the encoder.
    func encodeFuture<E>(_ future: Future<E>) throws
}

/// Conforms future to Encodable
extension Future: Encodable {
    /// See Encodable.encode
    public func encode(to encoder: Encoder) throws {
        if let encoder = encoder as? FutureEncoder {
            try encoder.encodeFuture(self)
        }
    }
}
