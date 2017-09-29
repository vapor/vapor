import Foundation
import Bits
import Async

/// Hashes the contents of a byte stream
///
/// When done hashing the stream, call `complete` to receive the hash and reset the hash to it's original state
public class ByteStreamHasher<H: Hash> : Async.InputStream {
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
    
    /// See `BaseStream.onClose`
    public var onClose: CloseHandler?
    
    /// See `BaseStream.errorStream`
    public var errorStream: ErrorHandler?
    
    /// The hash context
    let context = H()
}

/// Hashes the contents of a byte stream
///
/// When done hashing the stream, call `complete` to receive the hash and reset the hash to it's original state
///
/// Cascades the inputstream to the output stream without any changes.
public final class PassthroughByteStreamHasher<H: Hash> : ByteStreamHasher<H>, Async.OutputStream {
    /// See `InputStream` for details
    public override func inputStream(_ input: ByteBuffer) {
        super.inputStream(input)
        self.outputStream?(input)
    }
    
    /// The output is equal to the input
    public typealias Output = ByteBuffer
    
    /// This handler will receive the hash's raw input
    public var outputStream: OutputHandler?
}
