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
    open func close() {
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
    
    /// Writes all data from the pointer's position with the length specified to this socket.
    open func write(max: Int, from buffer: ByteBuffer) throws -> Int {
        guard let pointer = buffer.baseAddress else {
            return 0
        }
        
        let sent = send(descriptor, pointer, max, 0)
        guard sent != -1 else {
            switch errno {
            case EINTR:
                // try again
                return try write(max: max, from: buffer)
            case ECONNRESET, EBADF:
                // closed by peer, need to close this side.
                // Since this is not an error, no need to throw unless the close
                // itself throws an error.
                self.close()
                return 0
            default:
                throw Error.posix(errno, identifier: "write")
            }
        }
        
        return sent
    }
    
    /// Read data from the socket into the supplied buffer.
    /// Returns the amount of bytes actually read.
    open func read(max: Int, into buffer: MutableByteBuffer) throws -> Int {
        let receivedBytes = libc.read(descriptor, buffer.baseAddress.unsafelyUnwrapped, max)
        
        guard receivedBytes != -1 else {
            switch errno {
            case EINTR:
                // try again
                return try read(max: max, into: buffer)
            case ECONNRESET:
                // closed by peer, need to close this side.
                // Since this is not an error, no need to throw unless the close
                // itself throws an error.
                _ = close()
                return 0
            case EAGAIN:
                // timeout reached (linux)
                return 0
            default:
                throw Error.posix(errno, identifier: "read")
            }
        }
        
        guard receivedBytes > 0 else {
            // receiving 0 indicates a proper close .. no error.
            // attempt a close, no failure possible because throw indicates already closed
            // if already closed, no issue.
            // do NOT propogate as error
            _ = close()
            return 0
        }
        
        return receivedBytes
    }
}
