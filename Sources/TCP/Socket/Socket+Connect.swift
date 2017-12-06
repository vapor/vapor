import Async
import Dispatch
import COperatingSystem

extension TCPSocket {
    /// connect - initiate a connection on a socket
    /// http://man7.org/linux/man-pages/man2/connect.2.html
    public mutating func connect(hostname: String, port: UInt16) throws {
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
        guard res == 0 || (isNonBlocking && errno == EINPROGRESS) else {
            throw TCPError.posix(errno, identifier: "connect")
        }
        
        self.address = Address(storage: info.pointee.ai_addr.pointee)
    }
}
