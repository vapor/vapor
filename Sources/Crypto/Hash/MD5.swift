import Bits
import Foundation

fileprivate let s: [UInt32] = [ 7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,
                                5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,
                                4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,
                                6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21]

fileprivate let k: [UInt32] = [ 0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
                                0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
                                0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
                                0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
                                0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
                                0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
                                0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
                                0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
                                0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
                                0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
                                0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
                                0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
                                0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
                                0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
                                0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
                                0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391]

fileprivate let chunkSize = 64

public final class MD5 : Hash {
    public static let littleEndian = true
    public static let chunkSize = 64
    public static let digestSize = 16
    
    // The initial hash
    var a0: UInt32 = 0x67452301
    var b0: UInt32 = 0xefcdab89
    var c0: UInt32 = 0x98badcfe
    var d0: UInt32 = 0x10325476
    
    // Working variables
    var a1: UInt32 = 0
    var b1: UInt32 = 0
    var c1: UInt32 = 0
    var d1: UInt32 = 0
    
    var F: UInt32 = 0
    var g: Int = 0
    var Mg: UInt32 = 0
    
    public var remainder = MutableBytesPointer.allocate(capacity: 64)
    public var containedRemainder = 0
    public var totalLength: UInt64 = 0
    
    deinit {
        self.remainder.deallocate(capacity: 63)
    }
    
    public func reset() {
        a0 = 0x67452301
        b0 = 0xefcdab89
        c0 = 0x98badcfe
        d0 = 0x10325476
        containedRemainder = 0
        totalLength = 0
    }
    
    public init() {
        remainder.initialize(to: 0, count: 64)
    }
    
    public var hash: Data {
        var buffer = Data()
        buffer.reserveCapacity(16)
        
        func convert(_ int: UInt32) {
            let int = int.littleEndian
            
            buffer.append(UInt8(int & 0xff))
            buffer.append(UInt8((int >> 8) & 0xff))
            buffer.append(UInt8((int >> 16) & 0xff))
            buffer.append(UInt8((int >> 24) & 0xff))
        }
        
        convert(a0)
        convert(b0)
        convert(c0)
        convert(d0)
        
        return buffer
    }
    
    public func update(pointer: BytesPointer) {
        a1 = a0
        b1 = b0
        c1 = c0
        d1 = d0
        
        for i in 0...63 {
            switch i {
            case 0...15:
                F = (b1 & c1) | ((~b1) & d1)
                g = i
            case 16...31:
                F = (d1 & b1) | ((~d1) & c1)
                g = (5 &* i &+ 1) % 16
            case 32...47:
                F = b1 ^ c1 ^ d1
                g = (3 &* i &+ 5) % 16
            default:
                F = c1 ^ (b1 | (~d1))
                g = (7 &* i) % 16
            }
            
            Mg = pointer.advanced(by: g << 2).withMemoryRebound(to: UInt32.self, capacity: 1, { $0.pointee })
            
            F = F &+ a1 &+ k[i] &+ Mg
            a1 = d1
            d1 = c1
            c1 = b1
            b1 = b1 &+ leftRotate(F, count: s[i])
        }
        
        a0 = a0 &+ a1
        b0 = b0 &+ b1
        c0 = c0 &+ c1
        d0 = d0 &+ d1
    }
}

fileprivate func leftRotate(_ x: UInt32, count c: UInt32) -> UInt32 {
    return (x << c) | (x >> (32 - c))
}
