import Core
import Dispatch
import libc

/// Any TCP socket. It doesn't specify being a server or client yet.
public class Socket {
    /// The file descriptor related to this socket
    public let descriptor: Descriptor

    /// The remote's address
    public var address: sockaddr_storage?
    
    /// True if the socket is non blocking
    public let isNonBlocking: Bool

    /// True if the socket should re-use addresses
    public let shouldReuseAddress: Bool
    
    /// Will be triggered before closing the socket, as part of the cleanup process
    public var beforeClose: (()->())? = nil

    /// Creates a TCP socket around an existing descriptor
    public init(
        established: Descriptor,
        isNonBlocking: Bool,
        shouldReuseAddress: Bool
    ) {
        self.descriptor = established
        self.isNonBlocking = isNonBlocking
        self.shouldReuseAddress = shouldReuseAddress
    }
    
    /// Creates a new TCP socket
    public convenience init(
        isNonBlocking: Bool = true,
        shouldReuseAddress: Bool = true
    ) throws {
        let sockfd = socket(AF_INET, SOCK_STREAM, 0)
        guard sockfd > 0 else {
            throw Error.posix(errno, identifier: "socketCreate")
        }
        let descriptor = Descriptor(raw: sockfd)

        if isNonBlocking {
            // Set the socket to async/non blocking I/O
            guard fcntl(descriptor.raw, F_SETFL, O_NONBLOCK) == 0 else {
                throw Error.posix(errno, identifier: "setNonBlocking")
            }
        }

        if shouldReuseAddress {
            var yes = 1
            let intSize = socklen_t(MemoryLayout<Int>.size)
            guard setsockopt(descriptor.raw, SOL_SOCKET, SO_REUSEADDR, &yes, intSize) == 0 else {
                throw Error.posix(errno, identifier: "setReuseAddress")
            }
        }

        self.init(
            established: descriptor,
            isNonBlocking: isNonBlocking,
            shouldReuseAddress: shouldReuseAddress
        )
    }

    /// Closes the socket
    public func close() {
        beforeClose?()
        libc.close(descriptor.raw)
    }
    
    /// Returns a boolean describing if the socket is still healthy and open
    public var isConnected: Bool {
        var error = 0
        getsockopt(descriptor.raw, SOL_SOCKET, SO_ERROR, &error, nil)
        
        return error == 0
    }

    deinit {
        close()
    }
}
