import Async
import JunkDrawer
import Dispatch
import COperatingSystem
import Service

/// Accepts client connections to a socket.
///
/// Uses Async.OutputStream API to deliver accepted clients
/// with back pressure support. If overwhelmed, input streams
/// can cause the TCP server to suspend accepting new connections.
///
/// [Learn More →](https://docs.vapor.codes/3.0/sockets/tcp-server/)
public final class TCPServer: Async.OutputStream {
    /// See OutputStream.Output
    public typealias Output = TCPClient

    /// The dispatch queue that peers are accepted on.
    public let queue: DispatchQueue

    /// This server's event loops.
    /// Configuring these using the eventLoopCount at init.
    /// These will be supplied to requests at they arrive.
    public let eventLoops: [EventLoop]

    /// A closure that can dictate if a client will be accepted
    ///
    /// `true` for accepted, `false` for not accepted
    public typealias WillAccept = (TCPClient) -> (Bool)

    /// Controls whether or not to accept a client
    ///
    /// Useful for security purposes
    public var willAccept: WillAccept?

    /// This server's TCP socket.
    private let socket: TCPSocket

    /// A round robin view into the event loop array.
    private var eventLoopsIterator: LoopIterator<[EventLoop]>

    /// Keep a reference to the read source so it doesn't deallocate
    private var acceptSource: DispatchSourceRead?

    /// Use a basic output stream to implement server output stream.
    private var outputStream: BasicStream<TCPClient>?

    /// The amount of requested output remaining
    private var requestedOutputRemaining: UInt

    /// Creates a TCPServer from an existing TCPSocket.
    public init(socket: TCPSocket, eventLoops: [EventLoop], acceptQueue: DispatchQueue) {
        self.socket = socket
        self.queue = acceptQueue
        self.eventLoops = eventLoops
        self.eventLoopsIterator = try LoopIterator(eventLoops)
        self.requestedOutputRemaining = 0
    }

    /// Creates a new TCPServer.
    public convenience init(eventLoops: [EventLoop], acceptQueue: DispatchQueue) throws {
        try self.init(socket: .init(), eventLoops: eventLoops, acceptQueue: acceptQueue)
    }

    /// Starts listening for peers asynchronously
    public func start(hostname: String = "0.0.0.0", port: UInt16, backlog: Int32 = 128) throws {
        /// bind the socket and start listening
        try socket.bind(hostname: hostname, port: port)
        try socket.listen(backlog: backlog)

        /// initialize the internal output stream
        let outputStream = BasicStream<TCPClient>()

        /// handle downstream requesting data
        /// suspend will be called automatically if the
        /// remaining requested output count ever
        /// reaches zero.
        /// the downstream is expected to continue
        /// requesting additional output as it is ready.
        /// the server will automatically resume if
        /// additional clients are requested after
        /// suspend has been called
        outputStream.onRequestClosure = { count in self.queue.async { self.resume(count) } }

        /// handle downstream canceling output requests
        outputStream.onCancelClosure =  { self.queue.async { self.stop() } }

        self.outputStream = outputStream

    }

    /// See OutputStream.output
    public func output<S>(to inputStream: S) where S: InputStream, TCPServer.Output == S.Input {
        outputStream?.output(to: inputStream)
    }

    /// Stops the server
    public func stop() {
        socket.close()
        outputStream?.onClose()
        outputStream = nil
        if requestedOutputRemaining == 0 {
            /// dispatch sources must be resumed before
            /// deinitializing
            acceptSource?.resume()
        }
        acceptSource = nil
    }

    /// Resumes accepting clients if currently suspended
    /// and count is greater than 0
    private func resume(_ accepting: UInt) {
        let isSuspended = requestedOutputRemaining == 0
        requestedOutputRemaining += accepting

        if isSuspended && requestedOutputRemaining > 0 {
            ensureAcceptSource().resume()
        }
    }

    /// Suspends accepting clients.
    private func suspend() {
        print("suspending accept")
        ensureAcceptSource().suspend()
        requestedOutputRemaining = 0
    }

    /// Returns the existing accept source or creates
    /// and stores a new one
    private func ensureAcceptSource() -> DispatchSourceRead {
        guard let existing = acceptSource else {
            /// create a new accept source
            let source = DispatchSource.makeReadSource(
                fileDescriptor: socket.descriptor,
                queue: queue
            )

            /// handle a new accept
            source.setEventHandler(handler: acceptClient)

            /// handle a cancel event
            source.setCancelHandler(handler: stop)

            acceptSource = source
            return source
        }

        /// return the existing source
        return existing
    }

    /// Accepts a client and outputs to the output stream
    /// important: the socket _must_ be ready to accept a client
    /// as indicated by a read source.
    private func acceptClient() {
        /// it should be impossible to call this function when the
        /// outputStream is nil. fatalError here may help catch bugs.
        guard let outputStream = self.outputStream else {
            fatalError("\(#function) called while outputStream is nil")
        }

        let accepted: TCPSocket

        /// accept the new connection or throw an error
        do {
            accepted = try socket.accept()
        } catch {
            outputStream.onError(error)
            return
        }

        /// init a tcp client with the socket and assign it an event loop
        let client = TCPClient(
            socket: accepted,
            on: eventLoopsIterator.next()
        )

        /// check the will accept closure to approve this connection
        if let shouldAccept = willAccept, !shouldAccept(client) {
            client.stop()
            return
        }

        /// output the client
        outputStream.onInput(client)

        /// decrement remaining and check if
        /// we need to suspend accepting
        self.requestedOutputRemaining -= 1
        if self.requestedOutputRemaining == 0 {
            suspend()
        }
    }
}
