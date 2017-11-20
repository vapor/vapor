import Async
import Async
import Dispatch
import libc

/// A server socket can accept peers. Each accepted peer get's it own socket after accepting.
public final class Server: Async.OutputStream, ClosableStream {
    /// Closes the socket
    public func close() {
        socket.close()
    }
    
    // MARK: Stream
    public typealias Output = TCPClient
    
    /// See `BaseStream.onClose`
    public var onClose: CloseHandler?
    
    /// See `BaseStream.errorStream`
    public var errorStream: ErrorHandler?
    
    /// See `OutputStream.outputStream`
    public var outputStream: OutputHandler?

    // MARK: Dispatch

    /// The dispatch queue that peers are accepted on.
    public let queue: DispatchQueue

    // MARK: Internal

    let socket: Socket
    public let eventLoops: [EventLoop]
    var eventLoopsIterator: LoopIterator<[EventLoop]>
    var readSource: DispatchSourceRead?
    
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

    /// Creates a TCP server from an existing TCP socket.
    public init(socket: Socket, workerCount: Int) {
        self.socket = socket
        self.queue = DispatchQueue(label: "codes.vapor.net.tcp.server.main", qos: .background)
        var eventLoops: [EventLoop] = []
        /// important! this should be _less than_ the worker count
        /// to leave room for the accepting thread
        for i in 1..<workerCount {
            let queue = DispatchQueue(label: "codes.vapor.net.tcp.server.worker.\(i)", qos: .userInteractive)
            eventLoops.append(EventLoop(queue: queue))
        }
        eventLoopsIterator = LoopIterator(collection: eventLoops)
        self.eventLoops = eventLoops
    }

    /// Creates a new Server Socket
    public convenience init(workerCount: Int = 8) throws {
        let socket = try Socket()
        self.init(socket: socket, workerCount: workerCount)
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
            let socket: Socket
            do {
                socket = try self.socket.accept()
            } catch {
                self.errorStream?(error)
                return
            }

            let worker = self.eventLoopsIterator.next()!
            let client = TCPClient(socket: socket, worker: worker)
            
            guard self.willAccept(client) else {
                client.close()
                return
            }
            
            client.errorStream = self.errorStream
            self.output(client)
        }
        
        source.resume()
        readSource = source
    }
}
