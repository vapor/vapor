import Bits
import Core
import Dispatch
import libc

/// Any TCP socket. It doesn't specify being a server or client yet.
public final class Socket {
    /// The file descriptor related to this socket
    public let descriptor: Int32

    /// True if the socket is non blocking
    public let isNonBlocking: Bool

    /// True if the socket should re-use addresses
    public let shouldReuseAddress: Bool
    
    /// A write source that's used to check when the connection is open
    internal var writeSource: DispatchSourceWrite?

    /// Creates a TCP socket around an existing descriptor
    public init(
        established: Int32,
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
        
        if isNonBlocking {
            // Set the socket to async/non blocking I/O
            guard fcntl(sockfd, F_SETFL, O_NONBLOCK) == 0 else {
                throw Error.posix(errno, identifier: "setNonBlocking")
            }
        }

        if shouldReuseAddress {
            var yes = 1
            let intSize = socklen_t(MemoryLayout<Int>.size)
            guard setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &yes, intSize) == 0 else {
                throw Error.posix(errno, identifier: "setReuseAddress")
            }
        }

        self.init(
            established: sockfd,
            isNonBlocking: isNonBlocking,
            shouldReuseAddress: shouldReuseAddress
        )
    }

    /// Closes the socket
    public func close() {
        libc.close(descriptor)
    }
    
    /// Returns a boolean describing if the socket is still healthy and open
    public var isConnected: Bool {
        var error = 0
        getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &error, nil)
        
        return error == 0
    }

    deinit {
        close()
    }
}
