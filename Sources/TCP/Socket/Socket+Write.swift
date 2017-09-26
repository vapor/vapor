import Bits
import Foundation
import libc

extension Socket {
    /// Writes all data from the pointer's position with the length specified to this socket.
    public func write(max: Int, from buffer: ByteBuffer) throws -> Int {
        guard let pointer = buffer.baseAddress else {
            return 0
        }

        let sent = send(descriptor.raw, pointer, max, 0)
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
}

// MARK: Convenience

extension Socket {
    /// Copies bytes into a buffer and writes them to the socket.
    public func write(_ data: Data) throws -> Int {
        let buffer = ByteBuffer(start: data.withUnsafeBytes { $0 }, count: data.count)
        return try write(max: data.count, from: buffer)
    }
}
