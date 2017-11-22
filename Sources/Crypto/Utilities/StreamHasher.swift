import Foundation
import Bits
import Async

/// Hashes the contents of a byte stream
///
/// When done hashing the stream, call `complete` to receive the hash and reset the hash to it's original state
///
/// [Learn More →](https://docs.vapor.codes/3.0/crypto/hash/#streaming-hashes-async)
public class ByteStreamHasher<H, O> : Async.Stream where H: Hash {
    /// ByteStreamHasher accepts byte streams
    public typealias Input = ByteBuffer

    /// See OutputStream.Output
    public typealias Output = O

    /// The hash context
    let context = H()

    /// Use a basic stream to easily implement our output stream.
    var outputStream: BasicStream<O>
    
    /// Creates a new ByteStreamHasher that can hash a stream of bytes
    public required init() {
        self.outputStream = .init()
    }

    /// Completes the hash and returns the result
    public func complete() -> Data {
        defer {
            context.reset()
        }

        context.finalize()
        return context.hash
    }

    /// See InputStream.onInput
    public func onInput(_ input: ByteBuffer) {
        context.update(input)
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, O == I.Input {
        outputStream.onOutput(input)
    }
}


/// Hashes the contents of a byte stream
///
/// When done hashing the stream, call `complete` to receive the hash and reset the hash to it's original state
///
/// Cascades the inputstream to the output stream without any changes.
///
/// [Learn More →](https://docs.vapor.codes/3.0/crypto/hash/#using-streamhasher-as-a-transparent-component)
public final class PassthroughByteStreamHasher<H>: ByteStreamHasher<H, ByteBuffer> where H: Hash {
    /// See `InputStream` for details
    public override func onInput(_ input: ByteBuffer) {
        super.onInput(input)
        self.outputStream.onInput(input)
    }
}
