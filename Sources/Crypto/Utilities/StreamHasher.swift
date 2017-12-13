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
    private var outputRequest: OutputRequest?
    
    /// Creates a new ByteStreamHasher that can hash a stream of bytes
    public init() {}

    /// Completes the hash and returns the result
    public func complete() -> Data {
        defer { onClose() }
        context.finalize()
        return context.hash
    }

    /// See InputStream.onOutput
    public func onOutput(_ outputRequest: OutputRequest) {
        self.outputRequest = outputRequest
    }

    /// See InputStream.onInput
    public func onInput(_ input: ByteBuffer) {
        context.update(input)
        outputRequest?.requestOutput()
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        self.error = error
    }

    /// See InputStsream.onClose
    public func onClose() {
        context.reset()
    }
}
