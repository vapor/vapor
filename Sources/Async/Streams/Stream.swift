/// A stream is both an InputStream and an OutputStream
///
/// [Learn More →](https://docs.vapor.codes/3.0/async/streams-introduction/#implementing-an-example-stream)
public typealias Stream = InputStream & OutputStream

/// A type that accepts a stream of `Input`
///
/// [Learn More →](https://docs.vapor.codes/3.0/async/streams-introduction/#implementing-an-example-stream)
public protocol InputStream: BaseStream {
    /// The input type for this stream.
    /// For example: Request, ByteBuffer, Client
    associatedtype Input

    /// Input will be passed here as it is received.
    func inputStream(_ input: Input) throws
}

extension InputStream {
    /// Send input to stream, catching errors in
    /// the error stream.
    public func input(_ input: Input) {
        do {
            try inputStream(input)
        } catch {
            errorStream?(error)
        }
    }
}

/// A Stream that can be closed and can be listened to for closing
///
///
public protocol ClosableStream: BaseStream {
    /// A handler called when the stream closes.
    typealias CloseHandler = () -> ()
    
    /// Closes the connection
    func close()
    
    /// A function that gets called if the stream closes
    var onClose: CloseHandler? { get set }
}

extension ClosableStream {
    /// Closes the stream, calling the `onClose` handler.
    public func close() {
        onClose?()
    }

    /// Sets a CloseHandler callback on this stream.
    public func finally(_ onClose: @escaping CloseHandler) {
        self.onClose = onClose
    }
}

/// A type that emits `Ouptut` asynchronously and at unspecified moments
///
/// [Learn More →](https://docs.vapor.codes/3.0/async/streams-introduction/#implementing-an-example-stream)
public protocol OutputStream: BaseStream {
    /// The output type for this stream.
    /// For example: Request, ByteBuffer, Client
    associatedtype Output

    /// A closure that takes one onput.
    typealias OutputHandler = (Output) throws -> ()

    /// Pass output as it is generated to this stream.
    var outputStream: OutputHandler? { get set }
}

extension OutputStream {
    /// Send output to stream, catching errors in
    /// the error stream.
    public func output(_ output: Output) {
        do {
            try outputStream?(output)
        } catch {
            errorStream?(error)
        }
    }
}

/// Base stream protocol. Simply handles errors.
/// All streams are expected to reset themselves
/// after reporting an error and be ready for
/// additional incoming data.
///
/// [Learn More →](https://docs.vapor.codes/3.0/async/streams-introduction/#implementing-an-example-stream)
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
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/streams-introduction/#draining-streams)
    @discardableResult
    public func drain(_ handler: @escaping OutputHandler) -> Self {
        self.outputStream = handler
        return self
    }

    /// Drains the output stream into a closure
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/streams-introduction/#catching-stream-errors)
    @discardableResult
    public func `catch`(_ handler: @escaping ErrorHandler) -> Self {
        self.errorStream = handler
        return self
    }

    /// Drains the output stream into another input/output stream which can be chained.
    ///
    /// Also chains the errors to the other input/output stream
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/streams-basics/#chaining-streams)
    public func stream<S: Stream>(to stream: S) -> S where S.Input == Self.Output {
        stream.errorStream = self.errorStream
        self.outputStream = stream.inputStream
        return stream
    }

    /// Drains the output stream into an input stream.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/streams-basics/#draining-streams)
    public func drain<I: InputStream>(into input: I) where I.Input == Self.Output {
        input.errorStream = self.errorStream
        self.outputStream = input.inputStream
    }
}
