import Core
import Dispatch
import Foundation
import libc

// MARK: Convenience

extension Socket {
    /// Reads bytes and copies them into a Data struct.
    public func read(max: Int) throws -> Data {
        var pointer = MutableBytesPointer.allocate(capacity: max)
        defer {
            pointer.deallocate(capacity: max)
            pointer.deinitialize(count: max)
        }
        let buffer = MutableByteBuffer(start: pointer, count: max)
        let read = try self.read(max: max, into: buffer)
        let frame = ByteBuffer(start: pointer, count: read)
        return Data(buffer: frame)
    }
}
