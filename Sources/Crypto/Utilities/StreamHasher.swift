import Foundation
import Bits
import Async

/// Hashes the contents of a byte stream
///
/// When done hashing the stream, call `complete` to receive the hash and reset the hash to it's original state
///
/// [Learn More →](https://docs.vapor.codes/3.0/crypto/hash/#streaming-hashes-async)
public final class ByteStreamHasher<H: Hash> : Async.InputStream {
    /// See `InputStream` for details
    public func inputStream(_ input: ByteBuffer) {
        context.update(input)
    }
    
    /// Creates a new ByteStreamHasher that can hash a stream of bytes
    public required init() {}
    
    /// Completes the hash and returns the result
    public func complete() -> Data {
        defer {
            context.reset()
        }
        
        context.finalize()
        return context.hash
    }
    
    /// `ByteStreamHasher` accepts byte streams
    public typealias Input = ByteBuffer
    
    /// See `BaseStream.errorStream`
    public var errorStream: ErrorHandler?
    
    /// The hash context
    let context = H()
}
