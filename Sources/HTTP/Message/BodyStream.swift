import Async
import Bits

/// A stream of Bytes used for HTTP bodies
///
/// In HTTP/1 this becomes chunk encoded data
public final class BodyStream: Async.Stream {
    /// See InputStream.Input
    public typealias Input = ByteBuffer

    /// See OutputStream.Output
    public typealias Output = ByteBuffer

    /// The underlying stream
    private let stream = BasicStream<ByteBuffer>()

    /// Create a new body stream.
    public init() {}

    /// See InputStream.onOutput
    public func onOutput(_ outputRequest: OutputRequest) {
        stream.onOutput(outputRequest)
    }

    /// See InputStream.onInput
    public func onInput(_ input: ByteBuffer) {
        stream.onInput(input)
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        stream.onError(error)
    }

    /// See InputStream.onClose
    public func onClose() {
        stream.onClose()
    }

    /// See OutputStream.output
    public func output<S>(to inputStream: S) where S : InputStream, BodyStream.Output == S.Input {
        stream.output(to: inputStream)
    }
}
