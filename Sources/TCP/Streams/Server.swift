import Async
import Async
import Dispatch
import libc

/// A server socket can accept peers. Each accepted peer get's it own socket after accepting.
public final class TCPServer: Async.OutputStream, ClosableStream {
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
    public typealias AcceptHandler = (TCPClient) -> (Bool)

    /// Controls whether or not to accept a client
    ///
    /// Useful for security purposes
    public var willAccept: AcceptHandler = { _ in
        return true
    }

    /// See CloseableStream.onClose
    public var onClose: OnClose?

    /// This server's TCP socket.
    private let socket: TCPSocket

    /// A round robin view into the event loop array.
    private var eventLoopsIterator: LoopIterator<[EventLoop]>

    /// Keep a reference to the read source so it doesn't deallocate
    private var readSource: DispatchSourceRead?

    /// Use a basic output stream to implement server output stream.
    private var outputStream: BasicStream<Output> = .init()

    /// Creates a TCP server from an existing TCP socket.
    public init(socket: TCPSocket, eventLoopCount: Int) {
        self.socket = socket
        self.queue = DispatchQueue(label: "codes.vapor.net.tcp.server.main", qos: .background)
        var eventLoops: [EventLoop] = []
        /// important! this should be _less than_ the worker count
        /// to leave room for the accepting thread
        for i in 1..<eventLoopCount {
            let queue = DispatchQueue(label: "codes.vapor.net.tcp.server.worker.\(i)", qos: .userInteractive)
            eventLoops.append(EventLoop(queue: queue))
        }
        eventLoopsIterator = LoopIterator(collection: eventLoops)
        self.eventLoops = eventLoops
    }

    /// Creates a new Server Socket
    public convenience init(eventLoopCount: Int = 8) throws {
        let socket = try TCPSocket()
        self.init(socket: socket, eventLoopCount: eventLoopCount)
    }

    /// Starts listening for peers asynchronously
    ///
    /// - parameter maxIncomingConnections: The maximum backlog of incoming connections. Defaults to 4096.
    public func start(hostname: String = "0.0.0.0", port: UInt16, backlog: Int32 = 4096) throws {
        try socket.bind(hostname: hostname, port: port)
        try socket.listen(backlog: backlog)

        let source = DispatchSource.makeReadSource(
            fileDescriptor: socket.descriptor,
            queue: queue
        )
        
        source.setEventHandler {
            let socket: TCPSocket
            do {
                socket = try self.socket.accept()
            } catch {
                self.outputStream.onError(error)
                return
            }

            let worker = self.eventLoopsIterator.next()!
            let client = TCPClient(socket: socket, worker: worker)
            
            guard self.willAccept(client) else {
                client.close()
                return
            }

            self.outputStream.onInput(client)
        }
        
        source.resume()
        readSource = source
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, Output == I.Input {
        outputStream.onOutput(input)
    }

    /// See CloseableStream.close
    public func close() {
        socket.close()
        notifyClosed()
        /// reinit output stream to clear any ref cycles
        outputStream = .init()
    }
}
