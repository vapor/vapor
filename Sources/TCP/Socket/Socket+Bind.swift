import libc
import Foundation

extension TCPSocket {
    /// bind - bind a name to a socket
    /// http://man7.org/linux/man-pages/man2/bind.2.html
    public func bind(hostname: String = "0.0.0.0", port: UInt16) throws {
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

        res = libc.bind(descriptor, info.pointee.ai_addr, info.pointee.ai_addrlen)
        guard res == 0 else {
            throw TCPError.posix(errno, identifier: "bind")
        }
    }

    /// listen - listen for connections on a socket
    /// http://man7.org/linux/man-pages/man2/listen.2.html
    public func listen(backlog: Int32 = 4096) throws {
        let res = libc.listen(descriptor, backlog)
        guard res == 0 else {
            throw TCPError.posix(errno, identifier: "listen")
        }
    }

    /// accept, accept4 - accept a connection on a socket
    /// http://man7.org/linux/man-pages/man2/accept.2.html
    public func accept() throws -> TCPSocket {
        let (clientfd, address) = try Address.withSockaddrPointer { address -> Int32 in
            var size = socklen_t(MemoryLayout<sockaddr>.size)
            
            let descriptor = libc.accept(self.descriptor, address, &size)
            
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
