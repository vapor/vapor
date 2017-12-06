import Bits
import Dispatch
import Foundation
import COperatingSystem

extension TCPSocket {
    /// Read data from the socket into the supplied buffer.
    /// Returns the amount of bytes actually read.
    public func read(max: Int, into pointer: MutableBytesPointer) throws -> Int {
        let receivedBytes = COperatingSystem.read(descriptor, pointer, max)
        
        guard receivedBytes != -1 else {
            switch errno {
            case EINTR:
                // try again
                return try read(max: max, into: pointer)
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
                throw TCPError.posix(errno, identifier: "read")
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
    
    /// Reads bytes and copies them into a Data struct.
    public func read(max: Int) throws -> Data {
        var data = Data(repeating: 0, count: max)
        
        let read = try data.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
            return try self.read(max: max, into: pointer)
        }
        
        data.removeLast(data.count &- read)
        
        return data
    }
}
