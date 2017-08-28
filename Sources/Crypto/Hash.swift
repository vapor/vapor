import Core
import Foundation

public protocol Hash: class {
    /// The amount of processed bytes per chunk
    static var chunkSize: Int { get }
    
    /// The amount of bytes returned in the hash
    static var digestSize: Int { get }
    
    /// If `true`, treat the bitlength in the padding at littleEndian, bigEndian otherwise
    static var littleEndian: Bool { get }
    
    /// The current length of hashes bytes in bits
    var totalLength: UInt64 { get set }
    
    /// The resulting hash
    var hash: Data { get }
    
    /// The amount of bytes currently inside the `remainder` pointer.
    var containedRemainder: Int { get set }
    
    /// A buffer that keeps track of any bytes that cannot be processed until the chunk is full.  Size *must* be `chunkSize - 1`
    var remainder: MutableBytesPointer { get }
    
    /// Updates the hash using exactly one `chunkSize` of bytes referenced by a pointer
    func update(pointer: BytesPointer)
    
    /// Resets the hash's context to it's original state (reusing the context class)
    func reset()
    
    /// Creates a new empty hash
    init()
}

extension Hash {
    fileprivate var lastChunkSize: Int {
        return Self.chunkSize &- 8
    }
    
    /// Hashes the contents of this byte sequence
    ///
    /// Doesn't finalize the hash and thus doesn't return the data
    public static func hash(_ data: Data) -> Data {
        let h = Self()
        
        return Array(data).withUnsafeBufferPointer { buffer in
            h.finalize(buffer)
            return h.hash
        }
    }
    
    /// Hashes the contents of this byte sequence
    ///
    /// Doesn't finalize the hash and thus doesn't return the data
    public func finalize(_ data: Data) {
        let h = Self()
        
        Array(data).withUnsafeBufferPointer { buffer in
            h.finalize(buffer)
        }
    }
    
    /// Finalizes the hash by appending a `0x80` and `0x00` until there are 64 bits left. Then appends a `UInt64` with little or big endian as defined in the protocol implementation
    public func finalize(_ buffer: ByteBuffer? = nil) {
        let totalRemaining = containedRemainder + (buffer?.count ?? 0) + 1
        totalLength = totalLength &+ (UInt64(buffer?.count ?? 0) &* 8)
        
        // Append zeroes
        var zeroes = lastChunkSize &- (totalRemaining % Self.chunkSize)
        
        if zeroes > lastChunkSize {
            // Append another chunk of zeroes if we have more than 448 bits
            zeroes = (Self.chunkSize &+ (lastChunkSize &- zeroes)) &+ zeroes
        }
        
        // If there isn't enough room, add another big chunk of zeroes until there is room
        if zeroes < 0 {
            zeroes =  (8 &+ zeroes) + lastChunkSize
        }
        
        var length = [UInt8](repeating: 0, count: 8)
        
        // Append UInt64 length in bits
        _ = length.withUnsafeMutableBytes { length in
            memcpy(length.baseAddress!, &totalLength, 8)
        }
        
        // Little endian is reversed
        if !Self.littleEndian {
            length.reverse()
        }
        
        var lastBlocks: [UInt8]
        
        if let buffer = buffer {
            lastBlocks = Array(buffer)
        } else {
            lastBlocks = []
        }
        
        lastBlocks = lastBlocks + [0x80] + Data(repeating: 0, count: zeroes) + length
        
        var offset = 0
        
        lastBlocks.withUnsafeBufferPointer { buffer in
            let pointer = buffer.baseAddress!
            
            while offset < buffer.count {
                defer { offset = offset &+ Self.chunkSize }
                self.update(pointer: pointer.advanced(by: offset))
            }
        }
    }
    
    /// Updates the hash using the contents of this buffer
    ///
    /// Doesn't finalize the hash
    public func update(_ buffer: ByteBuffer) {
        totalLength = totalLength &+ UInt64(buffer.count)
        
        var buffer = buffer
        
        // If there was data from a previous chunk that needs to be processed, process that with this buffer, first
        if containedRemainder > 0 {
            let needed = Self.chunkSize &- containedRemainder
            
            guard let bufferPointer = buffer.baseAddress else {
                assertionFailure("Invalid buffer provided")
                return
            }
            
            if buffer.count >= needed {
                memcpy(remainder.advanced(by: containedRemainder), bufferPointer, needed)
                
                buffer = UnsafeBufferPointer(start: bufferPointer.advanced(by: needed), count: buffer.count &- needed)
            } else {
                memcpy(remainder.advanced(by: containedRemainder), bufferPointer, buffer.count)
                return
            }
        }
        
        // The buffer *must* have a baseAddress to read from
        guard var bufferPointer = buffer.baseAddress else {
            assertionFailure("Invalid hashing buffer provided")
            return
        }
        
        var bufferSize = buffer.count
        
        // Process the input in chunks of `chunkSize`
        while bufferSize >= Self.chunkSize {
            defer {
                bufferPointer = bufferPointer.advanced(by: Self.chunkSize)
                bufferSize = bufferSize &- Self.chunkSize
            }
            
            update(pointer: bufferPointer)
        }
        
        // Append the remaining data to the internal remainder buffer
        memcpy(remainder, bufferPointer, bufferSize)
        containedRemainder = bufferSize
    }
    
    /// Updates the hash with the contents of this byte sequence
    ///
    /// Does not finalize
    public func update<S: Sequence>(sequence: inout S) where S.Element == UInt8 {
        Array(sequence).withUnsafeBufferPointer { buffer in
            update(buffer)
        }
    }
}
