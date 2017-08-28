import Foundation
import Core

/// Hashes the contents of a byte stream
///
/// When done hashing the stream, call `complete` to receive the hash and reset the hash to it's original state
public class ByteStreamHasher<H: Hash> : Core.Stream {
    /// See `InputStream` for details
    public func inputStream(_ input: ByteBuffer) {
        context.update(input)
        self.outputStream?(input)
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
    
    /// The output is equal to the input
    public typealias Output = ByteBuffer
    
    /// This handler will receive the hash's raw input
    public var outputStream: OutputHandler?
    
    /// Unused. Can be used to receive errors, although hashes don't generate errors
    public var errorStream: ErrorHandler?
    
    /// The hash context
    let context = H()
}
