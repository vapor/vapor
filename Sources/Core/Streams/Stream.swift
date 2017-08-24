/// A stream is both an InputStream and an OutputStream
public typealias Stream = InputStream & OutputStream

public protocol InputStream: BaseStream {
    /// The input type for this stream.
    /// For example: Request, ByteBuffer, Client
    associatedtype Input

    /// Input will be passed here as it is received.
    func inputStream(_ input: Input)
}

public protocol OutputStream: BaseStream {
    /// The output type for this stream.
    /// For example: Request, ByteBuffer, Client
    associatedtype Output

    /// A closure that takes one onput.
    typealias OutputHandler = (Output) -> ()

    /// Pass output as it is generated to this stream.
    var outputStream: OutputHandler? { get set }
}

/// Base stream protocol. Simply handles errors.
/// All streams are expected to reset themselves
/// after reporting an error and be ready for
/// additional incoming data.
public protocol BaseStream: class {
    /// A closure that takes one error.
    typealias ErrorHandler = (Error) -> ()

    /// Pass any errors that are thrown to
    /// the error stream
    var errorStream: ErrorHandler? { get set }
}

// MARK: Convenience

extension OutputStream {
    /// Drains the output stream into a closure.
    public func drain(_ handler: @escaping OutputHandler) {
        self.outputStream = handler
    }

    /// Drains the output stream into another
    /// input/output stream which can be chained.
    public func stream<S: Stream>(to stream: S) -> S where S.Input == Self.Output {
        stream.errorStream = self.errorStream
        self.outputStream = stream.inputStream
        return stream
    }

    /// Drains the output stream into an input stream.
    public func drain<I: InputStream>(into input: I) where I.Input == Self.Output {
        input.errorStream = self.errorStream
        self.outputStream = input.inputStream
    }
}
