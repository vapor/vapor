import Bits
import Foundation

public final class SHA512 : SHA2_64 {
    /// If `true`, treat the bitlength in the padding at littleEndian, bigEndian otherwise
    public static let littleEndian = false
    
    /// The amount of bytes returned in the hash
    public static let digestSize = 64
    
    /// The amount of processed bytes per chunk
    public static let chunkSize = 128
    
    /// A buffer that keeps track of any bytes that cannot be processed until the chunk is full.
    public var remainder = MutableBytesPointer.allocate(capacity: 128)
    
    /// The amount of bytes currently inside the `remainder` pointer.
    public var containedRemainder = 0
    
    /// The current length of hashes bytes in bits
    public var totalLength: UInt64 = 0
    
    deinit {
        self.remainder.deallocate(capacity: 127)
    }
    
    /// The resulting hash
    public var hash: Data {
        var buffer = Data()
        buffer.reserveCapacity(32)
        
        func convert(_ int: UInt64) {
            let int = int.bigEndian
            
            buffer.append(UInt8(int & 0xff))
            buffer.append(UInt8((int >> 8) & 0xff))
            buffer.append(UInt8((int >> 16) & 0xff))
            buffer.append(UInt8((int >> 24) & 0xff))
            buffer.append(UInt8((int >> 32) & 0xff))
            buffer.append(UInt8((int >> 40) & 0xff))
            buffer.append(UInt8((int >> 48) & 0xff))
            buffer.append(UInt8((int >> 56) & 0xff))
        }
        
        convert(h0)
        convert(h1)
        convert(h2)
        convert(h3)
        convert(h4)
        convert(h5)
        convert(h6)
        convert(h7)
        
        return buffer
    }
    
    public init() {    }
    
    /// MARK - The standard hash settings hash
    
    var h0: UInt64 = 0x6a09e667f3bcc908
    var h1: UInt64 = 0xbb67ae8584caa73b
    var h2: UInt64 = 0x3c6ef372fe94f82b
    var h3: UInt64 = 0xa54ff53a5f1d36f1
    var h4: UInt64 = 0x510e527fade682d1
    var h5: UInt64 = 0x9b05688c2b3e6c1f
    var h6: UInt64 = 0x1f83d9abfb41bd6b
    var h7: UInt64 = 0x5be0cd19137e2179
    
    public func reset() {
        h0 = 0x6a09e667f3bcc908
        h1 = 0xbb67ae8584caa73b
        h2 = 0x3c6ef372fe94f82b
        h3 = 0xa54ff53a5f1d36f1
        h4 = 0x510e527fade682d1
        h5 = 0x9b05688c2b3e6c1f
        h6 = 0x1f83d9abfb41bd6b
        h7 = 0x5be0cd19137e2179
        containedRemainder = 0
        totalLength = 0
    }
    
    var a: UInt64 = 0
    var b: UInt64 = 0
    var c: UInt64 = 0
    var d: UInt64 = 0
    var e: UInt64 = 0
    var f: UInt64 = 0
    var g: UInt64 = 0
    var h: UInt64 = 0
}


public final class SHA384: SHA2_64 {
    /// If `true`, treat the bitlength in the padding at littleEndian, bigEndian otherwise
    public static let littleEndian = false
    
    /// The amount of bytes returned in the hash
    public static let digestSize = 48
    
    /// The amount of processed bytes per chunk
    public static let chunkSize = 128
    
    /// A buffer that keeps track of any bytes that cannot be processed until the chunk is full.
    public var remainder = MutableBytesPointer.allocate(capacity: 128)
    
    /// The amount of bytes currently inside the `remainder` pointer.
    public var containedRemainder = 0
    
    /// The current length of hashes bytes in bits
    public var totalLength: UInt64 = 0
    
    deinit {
        self.remainder.deallocate(capacity: 127)
    }
    
    /// The resulting hash
    public var hash: Data {
        var buffer = Data()
        buffer.reserveCapacity(32)
        
        func convert(_ int: UInt64) {
            let int = int.bigEndian
            
            buffer.append(UInt8(int & 0xff))
            buffer.append(UInt8((int >> 8) & 0xff))
            buffer.append(UInt8((int >> 16) & 0xff))
            buffer.append(UInt8((int >> 24) & 0xff))
            buffer.append(UInt8((int >> 32) & 0xff))
            buffer.append(UInt8((int >> 40) & 0xff))
            buffer.append(UInt8((int >> 48) & 0xff))
            buffer.append(UInt8((int >> 56) & 0xff))
        }
        
        convert(h0)
        convert(h1)
        convert(h2)
        convert(h3)
        convert(h4)
        convert(h5)
        
        return buffer
    }
    
    public init() {    }
    
    /// MARK - The standard hash settings hash
    
    var h0: UInt64 = 0xcbbb9d5dc1059ed8
    var h1: UInt64 = 0x629a292a367cd507
    var h2: UInt64 = 0x9159015a3070dd17
    var h3: UInt64 = 0x152fecd8f70e5939
    var h4: UInt64 = 0x67332667ffc00b31
    var h5: UInt64 = 0x8eb44a8768581511
    var h6: UInt64 = 0xdb0c2e0d64f98fa7
    var h7: UInt64 = 0x47b5481dbefa4fa4
    
    public func reset() {
        h0 = 0xcbbb9d5dc1059ed8
        h1 = 0x629a292a367cd507
        h2 = 0x9159015a3070dd17
        h3 = 0x152fecd8f70e5939
        h4 = 0x67332667ffc00b31
        h5 = 0x8eb44a8768581511
        h6 = 0xdb0c2e0d64f98fa7
        h7 = 0x47b5481dbefa4fa4
        containedRemainder = 0
        totalLength = 0
    }
    
    var a: UInt64 = 0
    var b: UInt64 = 0
    var c: UInt64 = 0
    var d: UInt64 = 0
    var e: UInt64 = 0
    var f: UInt64 = 0
    var g: UInt64 = 0
    var h: UInt64 = 0
}
