import Bits
import Dispatch
import COperatingSystem

/// Accepts client connections to a socket.
///
/// Uses Async.OutputStream API to deliver accepted clients
/// with back pressure support. If overwhelmed, input streams
/// can cause the TCP server to suspend accepting new connections.
///
/// [Learn More →](https://docs.vapor.codes/3.0/sockets/tcp-server/)
public struct TCPServer {
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

    /// Creates a TCPServer from an existing TCPSocket.
    public init(socket: TCPSocket) throws {
        self.socket = socket
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
    public mutating func accept() throws -> TCPClient? {
        let accepted = try socket.accept()

        /// init a tcp client with the socket and assign it an event loop
        let client = TCPClient(socket: accepted)

        /// check the will accept closure to approve this connection
        if let shouldAccept = willAccept, !shouldAccept(client) {
            client.close()
            return nil
        }

        /// output the client
        return client
    }

    /// Stops the server
    public func stop() {
        socket.close()
    }
}

import COperatingSystem
import Foundation

extension TCPSocket {
    /// bind - bind a name to a socket
    /// http://man7.org/linux/man-pages/man2/bind.2.html
    fileprivate func bind(hostname: String = "0.0.0.0", port: UInt16) throws {
        var hints = addrinfo()

        // Support both IPv4 and IPv6
        hints.ai_family = AF_INET

        // Specify that this is a TCP Stream
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP

        // If the AI_PASSIVE flag is specified in hints.ai_flags, and node is
        // NULL, then the returned socket addresses will be suitable for
        // bind(2)ing a socket that will accept(2) connections.
        hints.ai_flags = AI_PASSIVE


        // Look ip the sockeaddr for the hostname
        var result: UnsafeMutablePointer<addrinfo>?

        var res = getaddrinfo(hostname, port.description, &hints, &result)
        guard res == 0 else {
            throw TCPError.posix(
                errno,
                identifier: "getAddressInfo",
                possibleCauses: [
                    "The address that binding was attempted on does not refer to your machine."
                ],
                suggestedFixes: [
                    "Bind to `0.0.0.0` or to your machine's IP address"
                ]
            )
        }
        defer {
            freeaddrinfo(result)
        }

        guard let info = result else {
            throw TCPError(identifier: "unwrapAddress", reason: "Could not unwrap address info.")
        }

        res = COperatingSystem.bind(descriptor, info.pointee.ai_addr, info.pointee.ai_addrlen)
        guard res == 0 else {
            throw TCPError.posix(errno, identifier: "bind")
        }
    }

    /// listen - listen for connections on a socket
    /// http://man7.org/linux/man-pages/man2/listen.2.html
    fileprivate func listen(backlog: Int32 = 4096) throws {
        let res = COperatingSystem.listen(descriptor, backlog)
        guard res == 0 else {
            throw TCPError.posix(errno, identifier: "listen")
        }
    }

    /// accept, accept4 - accept a connection on a socket
    /// http://man7.org/linux/man-pages/man2/accept.2.html
    fileprivate func accept() throws -> TCPSocket {
        let (clientfd, address) = try TCPAddress.withSockaddrPointer { address -> Int32 in
            var size = socklen_t(MemoryLayout<sockaddr>.size)

            let descriptor = COperatingSystem.accept(self.descriptor, address, &size)

            guard descriptor > 0 else {
                throw TCPError.posix(errno, identifier: "accept")
            }

            return descriptor
        }

        let socket = TCPSocket(
            established: clientfd,
            isNonBlocking: isNonBlocking,
            shouldReuseAddress: shouldReuseAddress,
            address: address
        )

        return socket
    }
}

