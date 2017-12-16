import Async
import Bits
import Dispatch
import JunkDrawer

/// Stream representation of a TCP server.
public final class TCPClientStream<EventLoop>: OutputStream, ConnectionContext where EventLoop: Async.EventLoop {
    /// See OutputStream.Output
    public typealias Output = TCPPeer<EventLoop>

    /// The server being streamed
    public var server: TCPServer

    /// This stream's event loop
    public let eventLoop: EventLoop

    /// Downstream client and eventloop input stream
    private var downstream: AnyInputStream<Output>?

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
    }

    /// See OutputStream.output
    public func output<S>(to inputStream: S) where S: InputStream, S.Input == Output {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }

    /// See ConnectionContext.connection
    public func connection(_ event: ConnectionEvent) {
        switch event {
        case.request(let count):
            /// handle downstream requesting data
            /// suspend will be called automatically if the
            /// remaining requested output count ever
            /// reaches zero.
            /// the downstream is expected to continue
            /// requesting additional output as it is ready.
            /// the server will automatically resume if
            /// additional clients are requested after
            /// suspend has been called
            eventLoop.queue.async {
                self.request(count)
            }
        case .cancel:
            /// handle downstream canceling output requests
            eventLoop.queue.async {
                self.cancel()
            }
        }
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
        downstream?.close()
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

            downstream?.next(.init(
                client: client,
                eventLoop: eventLoop
            ))

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
            downstream?.error(error)
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

/// A client that has been accepted by
/// the TCP client stream.
public final class TCPPeer<EventLoop>: Stream where EventLoop: Async.EventLoop {
    /// See InputStream.Input
    public typealias Input = ByteBuffer

    // See OutputStream.Output
    public typealias Output = ByteBuffer

    /// The accepted client
    public let client: TCPClient

    /// The event loop this client was accepted on
    public let eventLoop: EventLoop

    /// Underlying byte stream
    private let byteStream: DispatchSocketStream<TCPSocket>

    /// Creates a new TCP accepted client
    init(client: TCPClient, eventLoop: EventLoop) {
        self.client = client
        self.eventLoop = eventLoop
        byteStream = client.stream(on: eventLoop)
    }

    /// See InputStream.input
    public func input(_ event: InputEvent<ByteBuffer>) {
        byteStream.input(event)
    }

    /// See OutputStream.output
    public func output<S>(to inputStream: S) where S : InputStream, S.Input == ByteBuffer {
        byteStream.output(to: inputStream)
    }
}


extension TCPServer {
    /// Create a stream for this TCP server.
    /// - parameter on: the event loop to accept clients on
    /// - parameter assigning: the event loops to assign to incoming clients
    public func stream<EventLoop>(on eventLoop: EventLoop, assigning eventLoops: [EventLoop]) -> TCPClientStream<EventLoop>
        where EventLoop: Async.EventLoop
    {
        return .init(server: self, on: eventLoop, assigning: eventLoops)
    }
}
