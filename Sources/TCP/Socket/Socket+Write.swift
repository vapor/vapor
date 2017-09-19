import Core
import Foundation
import libc

// MARK: Convenience

extension Socket {
    /// Copies bytes into a buffer and writes them to the socket.
    public func write(_ data: Data) throws -> Int {
        let buffer = ByteBuffer(start: data.withUnsafeBytes { $0 }, count: data.count)
        return try write(max: data.count, from: buffer)
    }
}
