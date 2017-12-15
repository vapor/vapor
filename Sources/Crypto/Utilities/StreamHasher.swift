import Foundation
import Bits
import Async

/// Hashes the contents of a byte stream
///
/// When done hashing the stream, call `complete` to receive the hash and reset the hash to it's original state
///
/// [Learn More →](https://docs.vapor.codes/3.0/crypto/hash/#streaming-hashes-async)
public final class ByteStreamHasher<Hash>: Async.InputStream where Hash: Crypto.Hash {
    /// ByteStreamHasher accepts byte streams
    public typealias Input = ByteBuffer

    /// The hash context
    private let context = Hash()

    /// Any errors that have arisen while hashing
    private var error: Error?

    /// The current output request
    private var upstream: ConnectionContext?
    
    /// Creates a new ByteStreamHasher that can hash a stream of bytes
    public init() {}

    /// Completes the hash and returns the result
    public func complete() -> Data {
        defer { close() }
        context.finalize()
        return context.hash
    }

    public func input(_ event: InputEvent<ByteBuffer>) {
        switch event {
        case .close: context.reset()
        case .connect(let upstream):
            self.upstream = upstream
            upstream.request()
        case .error(let error): self.error = error
        case .next(let input):
            context.update(input)
            upstream?.request()
        }
    }
}
