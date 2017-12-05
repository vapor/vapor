import Async
import Core
import Dispatch
import libc
import Service

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

    /// This server's TCP socket.
    private let socket: TCPSocket

    /// A round robin view into the event loop array.
    private var eventLoopsIterator: LoopIterator<[EventLoop]>

    /// Keep a reference to the read source so it doesn't deallocate
    private var readSource: DispatchSourceRead?

    /// Use a basic output stream to implement server output stream.
    private var outputStream: BasicStream<Output> = .init()

    /// Creates a TCP server from an existing TCP socket.
    public init(socket: TCPSocket, eventLoops: [EventLoop]) {
        self.socket = socket
        self.queue = DispatchQueue(label: "codes.vapor.net.tcp.server", qos: .background)
        self.eventLoops = eventLoops
        self.eventLoopsIterator = LoopIterator(collection: eventLoops)
    }

    /// Creates a new socket
    public convenience init(eventLoops: [EventLoop]) throws {
        try self.init(socket: .init(), eventLoops: eventLoops)
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

            let eventLoop = self.eventLoopsIterator.next()!
            /// FIXME: pass worker
            let client = TCPClient(socket: socket, on: eventLoop)
            
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

    /// See ClosableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }

    /// See CloseableStream.close
    public func close() {
        socket.close()
        outputStream.close()
        /// reinit output stream to clear any ref cycles
        outputStream = .init()
    }
}
