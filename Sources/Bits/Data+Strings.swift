import Foundation

public let asciiCasingOffset = Byte.a - Byte.A

extension Data {
    /// Converts a data blob's uppercased ASCII characters to lowercased efficiently
    public func lowercasedASCIIString() -> Data {
        var lowercased = Data(repeating: 0, count: self.count)
        var writeIndex = 0
        
        for i in self.startIndex..<self.endIndex {
            if self[i] >= .A && self[i] <= .Z {
                lowercased[writeIndex] = self[i] &+ asciiCasingOffset
            } else {
                lowercased[writeIndex] = self[i]
            }
            
            writeIndex = writeIndex &+ 1
        }
        
        return lowercased
    }
}

extension Data {
    /// Reads from a `Data` buffer using a `BufferPointer` rather than a normal pointer
    public func withByteBuffer<T>(_ closure: (ByteBuffer) throws -> T) rethrows -> T {
        return try self.withUnsafeBytes { (pointer: BytesPointer) in
            let buffer = ByteBuffer(start: pointer,count: self.count)
            
            return try closure(buffer)
        }
    }

    /// Reads from a `Data` buffer using a `BufferPointer` rather than a normal pointer
    public mutating func withMutableByteBuffer<T>(_ closure: (MutableByteBuffer) throws -> T) rethrows -> T {
        let count = self.count
        return try self.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
            let buffer = MutableByteBuffer(start: pointer,count: count)
            return try closure(buffer)
        }
    }
}
