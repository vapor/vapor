import Async
import Dispatch

/// Stream representation of a TCP server.
public final class TCPServerStream: OutputStream {
    /// See OutputStream.Output
    public typealias Output = TCPClient

    /// The server being streamed
    public var server: TCPServer

    /// The dispatch queue that peers are accepted on.
    public let eventLoop: EventLoop

    /// Use a basic output stream to implement server output stream.
    private let outputStream: BasicStream<TCPClient>

    /// The amount of requested output remaining
    private var requestedOutputRemaining: UInt

    /// Keep a reference to the read source so it doesn't deallocate
    private var acceptSource: DispatchSourceRead?

    /// Use TCPServer.stream to create
    internal init(server: TCPServer, on eventLoop: EventLoop) {
        self.server = server
        self.eventLoop = eventLoop
        self.requestedOutputRemaining = 0

        /// initialize the internal output stream
        self.outputStream = BasicStream<TCPClient>()

        /// handle downstream requesting data
        /// suspend will be called automatically if the
        /// remaining requested output count ever
        /// reaches zero.
        /// the downstream is expected to continue
        /// requesting additional output as it is ready.
        /// the server will automatically resume if
        /// additional clients are requested after
        /// suspend has been called
        outputStream.onRequestClosure = { count in eventLoop.queue.async { self.request(count) } }

        /// handle downstream canceling output requests
        outputStream.onCancelClosure =  { eventLoop.queue.async { self.cancel() } }
    }

    /// See OutputStream.output
    public func output<S>(to inputStream: S) where S: InputStream, S.Input == TCPClient {
        outputStream.output(to: inputStream)
    }

    /// Resumes accepting clients if currently suspended
    /// and count is greater than 0
    private func request(_ accepting: UInt) {
        let isSuspended = requestedOutputRemaining == 0
        requestedOutputRemaining += accepting

        if isSuspended && requestedOutputRemaining > 0 {
            ensureAcceptSource().resume()
        }
    }

    /// Cancels the stream
    private func cancel() {
        server.stop()
        outputStream.onClose()
        if requestedOutputRemaining == 0 {
            /// dispatch sources must be resumed before
            /// deinitializing
            acceptSource?.resume()
        }
        acceptSource = nil
    }

    /// Accepts a client and outputs to the stream
    private func accept() {
        do {
            let client = try server.accept()
            outputStream.onInput(client)

            /// decrement remaining and check if
            /// we need to suspend accepting
            self.requestedOutputRemaining -= 1
            if self.requestedOutputRemaining == 0 {
                print("suspending accept")
                ensureAcceptSource().suspend()
                requestedOutputRemaining = 0
            }
        } catch {
            outputStream.onError(error)
        }
    }

    /// Returns the existing accept source or creates
    /// and stores a new one
    private func ensureAcceptSource() -> DispatchSourceRead {
        guard let existing = acceptSource else {
            /// create a new accept source
            let source = DispatchSource.makeReadSource(
                fileDescriptor: server.socket.descriptor,
                queue: eventLoop.queue
            )

            /// handle a new accept
            source.setEventHandler(handler: accept)

            /// handle a cancel event
            source.setCancelHandler(handler: cancel)

            acceptSource = source
            return source
        }

        /// return the existing source
        return existing
    }
}

extension TCPServer {
    /// Create a stream for this TCP server.
    public func stream(on eventLoop: EventLoop) -> TCPServerStream {
        return TCPServerStream(server: self, on: eventLoop)
    }
}
