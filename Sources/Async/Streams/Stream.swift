/// A stream is both an InputStream and an OutputStream
///
/// http://localhost:8000/async/streams-introduction/#implementing-an-example-stream
public typealias Stream = InputStream & OutputStream

/// A type that accepts a stream of `Input`
///
/// http://localhost:8000/async/streams-introduction/#implementing-an-example-stream
public protocol InputStream: BaseStream {
    /// The input type for this stream.
    /// For example: Request, ByteBuffer, Client
    associatedtype Input

    /// Input will be passed here as it is received.
    func inputStream(_ input: Input)
}

/// A Stream that can be closed and can be listened to for closing
///
///
public protocol ClosableStream: BaseStream {
    /// Closes this stream and must notify the `closeNotification`
    func close()
    
    /// A function that gets called if the stream closes
    var closeNotification: SingleNotification<Void> { get }
}

/// A type that emits `Ouptut` notifications asynchronously and at unspecified moments
///
/// http://localhost:8000/async/streams-introduction/#implementing-an-example-stream
public protocol OutputStream: BaseStream, NotificationEmitter {
    /// Pass output as it is generated to this stream.
    var outputStream: NotificationCallback? { get set }
}

/// Base stream protocol. Simply handles errors.
/// All streams are expected to reset themselves
/// after reporting an error and be ready for
/// additional incoming data.
public protocol BaseStream: class {
    /// Pass any errors that are thrown to
    /// the error stream
    var errorNotification: SingleNotification<Error> { get }
}

// MARK: Convenience

extension OutputStream {
    /// Overrides the outputStream callback to capture output notifications using the new callback
    public func handleNotification(callback: @escaping ((Notification) -> ())) {
        self.outputStream = callback
    }
    
    /// Drains the output stream into a closure.
    ///
    /// http://localhost:8000/async/streams-basics/#draining-streams
    @discardableResult
    public func drain(_ handler: @escaping NotificationCallback) -> Self {
        self.outputStream = handler
        return self
    }
    
    /// A closure that takes one error.
    public typealias ErrorHandler = (Error) -> ()

    /// Drains the output stream into a closure
    ///
    /// http://localhost:8000/async/streams-basics/#catching-stream-errors
    @discardableResult
    public func `catch`(_ handler: @escaping ErrorHandler) -> Self {
        self.errorNotification.handleNotification(callback: handler)
        return self
    }

    /// Drains the output stream into another input/output stream which can be chained.
    ///
    /// Also chains the errors to the other input/output stream
    ///
    /// http://localhost:8000/async/streams-basics/#chaining-streams
    public func stream<S: Stream>(to stream: S) -> S where S.Input == Self.Notification {
        stream.catch(self.errorNotification.notify)
        self.outputStream = stream.inputStream
        return stream
    }

    /// Drains the output stream into an input stream.
    ///
    /// http://localhost:8000/async/streams-basics/#draining-streams
    public func drain<I: InputStream>(into input: I) where I.Input == Self.Notification {
        input.errorNotification.handleNotification(callback: self.errorNotification.notify)
        self.outputStream = input.inputStream
    }
}
