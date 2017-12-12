import Async
import Dispatch
import JunkDrawer

/// Stream representation of a TCP server.
public final class TCPClientStream: OutputStream {
    /// See OutputStream.Output
    public typealias Output = (TCPClient, EventLoop)

    /// The server being streamed
    public var server: TCPServer

    /// This stream's event loop
    public let eventLoop: EventLoop

    /// Use a basic output stream to implement server output stream.
    private let outputStream: BasicStream<Output>

    /// The amount of requested output remaining
    private var requestedOutputRemaining: UInt

    /// This server's event loops.
    /// Configuring these using the eventLoopCount at init.
    /// These will be supplied to requests at they arrive.
    public let eventLoops: [EventLoop]

    /// Keep a reference to the read source so it doesn't deallocate
    private var acceptSource: DispatchSourceRead?

    /// A round robin view into the event loop array.
    private var eventLoopsIterator: LoopIterator<[EventLoop]>

    /// Use TCPServer.stream to create
    internal init(server: TCPServer, on eventLoop: EventLoop, assigning eventLoops: [EventLoop]) {
        self.eventLoop = eventLoop
        self.server = server
        self.requestedOutputRemaining = 0
        self.eventLoops = eventLoops
        self.eventLoopsIterator = try! LoopIterator(eventLoops)

        /// initialize the internal output stream
        self.outputStream = BasicStream<Output>()

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
    public func output<S>(to inputStream: S) where S: InputStream, S.Input == Output {
        outputStream.output(to: inputStream)
    }

    /// Resumes accepting clients if currently suspended
    /// and count is greater than 0
    private func request(_ accepting: UInt) {
        let isSuspended = requestedOutputRemaining == 0
        if accepting == .max {
            requestedOutputRemaining = .max
        } else {
            requestedOutputRemaining += accepting
        }

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
            guard let client = try server.accept() else {
                // the client was rejected
                return
            }

            let eventLoop = eventLoopsIterator.next()
            outputStream.onInput((client, eventLoop))

            /// decrement remaining and check if
            /// we need to suspend accepting
            if requestedOutputRemaining != .max {
                requestedOutputRemaining -= 1
                if requestedOutputRemaining == 0 {
                    ensureAcceptSource().suspend()
                    requestedOutputRemaining = 0
                }
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
    /// - parameter on: the event loop to accept clients on
    /// - parameter assigning: the event loops to assign to incoming clients
    public func stream(on eventLoop: EventLoop, assigning eventLoops: [EventLoop]) -> TCPClientStream {
        return .init(server: self, on: eventLoop, assigning: eventLoops)
    }
}
