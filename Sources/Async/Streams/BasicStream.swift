/// A basic, generic stream implementation.
public final class BasicStream<Data>: Stream, ClosableStream {
    /// See InputStream.Input
    public typealias Input = Data

    /// See OutputStream.Output
    public typealias Output = Data

    /// See Stream.errorStream
    public var errorStream: ErrorHandler?

    /// See OutputStream.outputStream
    public var outputStream: OutputHandler?

    /// See ClosableStream.onClose
    public var onClose: CloseHandler?

    /// See InputStream.inputStream()
    public func inputStream(_ input: Data) {
        output(input)
    }

    /// Create a new BasicStream generic on the supplied type.
    public init(_ data: Data.Type = Data.self) {}
}
