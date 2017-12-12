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
public struct TCPServer {
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
    public let socket: TCPSocket

    /// A round robin view into the event loop array.
    private var eventLoopsIterator: LoopIterator<[EventLoop]>

    /// Creates a TCPServer from an existing TCPSocket.
    public init(socket: TCPSocket? = nil, eventLoops: [EventLoop]) throws {
        self.socket = try socket ?? .init()
        self.eventLoops = eventLoops
        self.eventLoopsIterator = try LoopIterator(eventLoops)
    }

    /// Starts listening for peers asynchronously
    public func start(hostname: String = "0.0.0.0", port: UInt16, backlog: Int32 = 128) throws {
        /// bind the socket and start listening
        try socket.bind(hostname: hostname, port: port)
        try socket.listen(backlog: backlog)
    }

    /// Accepts a client and outputs to the output stream
    /// important: the socket _must_ be ready to accept a client
    /// as indicated by a read source.
    public mutating func accept() throws -> TCPClient {
        let accepted = try socket.accept()

        /// init a tcp client with the socket and assign it an event loop
        let client = TCPClient(
            socket: accepted,
            on: eventLoopsIterator.next()
        )

        /// check the will accept closure to approve this connection
        if let shouldAccept = willAccept, !shouldAccept(client) {
            client.stop()
            throw TCPError(identifier: "clientRejected", reason: "Client was not accepted by TCP server.")
        }

        /// output the client
        return client
    }

    /// Stops the server
    public func stop() {
        socket.close()
    }
}
