import Async
import Bits
import Dispatch
import COperatingSystem
import JunkDrawer

/// Read and write byte buffers from a TCPClient.
///
/// These are usually created as output by a TCPServer.
///
/// [Learn More →](https://docs.vapor.codes/3.0/sockets/tcp-client/)
public final class TCPClient {
    /// The client stream's underlying socket.
    public var socket: TCPSocket

    /// Handles close events
    public typealias WillClose = () -> ()
    
    /// Will be triggered before closing the socket, as part of the cleanup process
    public var willClose: WillClose?

    /// Creates a new TCPClient from an existing TCPSocket.
    public init(socket: TCPSocket) {
        self.socket = socket
        self.socket.disablePipeSignal()
    }

    /// Attempts to connect to a server on the provided hostname and port
    public func connect(hostname: String, port: UInt16) throws  {
        try self.socket.connect(hostname: hostname, port: port)
    }

    /// Returns a boolean describing if the socket is still healthy and open
    public var isConnected: Bool {
        var error = 0
        getsockopt(socket.descriptor, SOL_SOCKET, SO_ERROR, &error, nil)
        return error == 0
    }

    /// Stops the client
    public func close() {
        willClose?()
        socket.close()
    }
}

extension TCPClient {
    /// Create a dispatch socket stream for this client.
    public func stream(on Worker: Worker) -> DispatchSocketStream<TCPSocket> {
        return socket.stream(on: Worker)
    }
}

extension TCPSocket {
    /// connect - initiate a connection on a socket
    /// http://man7.org/linux/man-pages/man2/connect.2.html
    fileprivate mutating func connect(hostname: String, port: UInt16) throws {
        var hints = addrinfo()

        // Support both IPv4 and IPv6
        hints.ai_family = AF_INET

        // Specify that this is a TCP Stream
        hints.ai_socktype = SOCK_STREAM

        // Look ip the sockeaddr for the hostname
        var result: UnsafeMutablePointer<addrinfo>?

        var res = getaddrinfo(hostname, port.description, &hints, &result)
        guard res == 0 else {
            throw TCPError.posix(
                errno,
                identifier: "getAddressInfo",
                possibleCauses: [
                    "The address supplied could not be resolved."
                ]
            )
        }
        defer {
            freeaddrinfo(result)
        }

        guard let info = result else {
            throw TCPError(identifier: "unwrapAddress", reason: "Could not unwrap address info.")
        }

        res = COperatingSystem.connect(descriptor, info.pointee.ai_addr, info.pointee.ai_addrlen)
        if res != 0 {
            switch errno {
            case EINTR:
                // the connection will now be made async regardless of socket type
                // http://www.madore.org/~david/computers/connect-intr.html
                if !isNonBlocking {
                    print("EINTR on a blocking socket")
                }
            case EINPROGRESS:
                if !isNonBlocking {
                    fatalError("EINPROGRESS on a blocking socket")
                }
            default: throw TCPError.posix(errno, identifier: "connect")
            }
        }

        self.address = TCPAddress(storage: info.pointee.ai_addr.pointee)
    }
}
