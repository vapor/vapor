import Bits
import Async
import Dispatch
import libc

/// Any TCP socket. It doesn't specify being a server or client yet.
public final class Socket {
    /// The file descriptor related to this socket
    public let descriptor: Int32

    /// The remote's address
    public var address: Address?
    
    /// True if the socket is non blocking
    public let isNonBlocking: Bool

    /// True if the socket should re-use addresses
    public let shouldReuseAddress: Bool
    
    /// A read source that's used to check when the connection is readable
    internal var readSource: DispatchSourceRead?
    
    /// A handler that gets called when closing the socket
    public typealias CloseHandler = (()->())
    
    /// Will be triggered before closing the socket, as part of the cleanup process
    public var didClose: CloseHandler? = nil
    
    /// A write source that's used to check when the connection is open
    internal var writeSource: DispatchSourceWrite?

    /// Creates a TCP socket around an existing descriptor
    public init(
        established: Int32,
        isNonBlocking: Bool,
        shouldReuseAddress: Bool,
        address: Address?
    ) {
        self.descriptor = established
        self.isNonBlocking = isNonBlocking
        self.shouldReuseAddress = shouldReuseAddress
        self.address = address
    }
    
    /// Creates a new TCP socket
    public convenience init(
        isNonBlocking: Bool = true,
        shouldReuseAddress: Bool = true
    ) throws {
        let sockfd = socket(AF_INET, SOCK_STREAM, 0)
        guard sockfd > 0 else {
            throw TCPError.posix(errno, identifier: "socketCreate")
        }
        
        if isNonBlocking {
            // Set the socket to async/non blocking I/O
            guard fcntl(sockfd, F_SETFL, O_NONBLOCK) == 0 else {
                throw TCPError.posix(errno, identifier: "setNonBlocking")
            }
        }

        if shouldReuseAddress {
            var yes = 1
            let intSize = socklen_t(MemoryLayout<Int>.size)
            guard setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &yes, intSize) == 0 else {
                throw TCPError.posix(errno, identifier: "setReuseAddress")
            }
        }

        self.init(
            established: sockfd,
            isNonBlocking: isNonBlocking,
            shouldReuseAddress: shouldReuseAddress,
            address: nil
        )
    }

    /// Closes the socket
    public func close() {
        libc.close(descriptor)
        didClose?()
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
