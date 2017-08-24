import Core
import Dispatch
import libc

/// A server socket can accept peers. Each accepted peer get's it own socket after accepting.
public final class Server: Core.OutputStream {
    // MARK: Stream
    public typealias Output = Client
    public var errorStream: ErrorHandler?
    public var outputStream: OutputHandler?

    // MARK: Dispatch

    /// The dispatch queue that peers are accepted on.
    public let queue: DispatchQueue

    // MARK: Internal

    let socket: Socket
    let workers: [DispatchQueue]
    var worker: LoopIterator<[DispatchQueue]>
    var readSource: DispatchSourceRead?

    /// Creates a TCP server from an existing TCP socket.
    public init(socket: Socket, workerCount: Int) {
        self.socket = socket
        self.queue = DispatchQueue(label: "codes.vapor.net.tcp.server.main", qos: .background)
        var workers: [DispatchQueue] = []
        for i in 1...workerCount {
            let worker = DispatchQueue(label: "codes.vapor.net.tcp.server.worker.\(i)", qos: .userInteractive)
            workers.append(worker)
        }
        worker = LoopIterator(collection: workers)
        self.workers = workers
    }

    /// Creates a new Server Socket
    public convenience init(workerCount: Int = 8) throws {
        let socket = try Socket()
        self.init(socket: socket, workerCount: workerCount)
    }

    /// Starts listening for peers asynchronously
    ///
    /// - parameter maxIncomingConnections: The maximum backlog of incoming connections. Defaults to 4096.
    public func start(hostname: String = "localhost", port: UInt16, backlog: Int32 = 4096) throws {
        try socket.bind(hostname: hostname, port: port)
        try socket.listen(backlog: backlog)

        readSource = socket.onReadable(queue: queue) {
            let socket: Socket
            do {
                socket = try self.socket.accept()
            } catch {
                self.errorStream?(error)
                return
            }

            let queue = self.worker.next()!
            let client = Client(socket: socket, queue: queue)
            client.errorStream = self.errorStream
            self.outputStream?(client)
        }
    }
}
