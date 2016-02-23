//
//  Copyright 2014-2016 Damian Kołakowski. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Foundation
#endif


extension String {
    
    var SHA1: String {
        return self.SHA1Array.reduce("") { el1, el2 in
            return el1 + String(el2, radix: 16, uppercase: false)
        }
    }
    
    var SHA1Array: [UInt8] {
        
        // Alghorithm from: https://en.wikipedia.org/wiki/SHA-1
        var message = [UInt8](self.utf8)
        
        var h0 = UInt32(littleEndian: 0x67452301)
        var h1 = UInt32(littleEndian: 0xEFCDAB89)
        var h2 = UInt32(littleEndian: 0x98BADCFE)
        var h3 = UInt32(littleEndian: 0x10325476)
        var h4 = UInt32(littleEndian: 0xC3D2E1F0)
        
        // ml = message length in bits (always a multiple of the number of bits in a character).
        let ml = UInt64(message.count * 8)
        
        // append the bit '1' to the message e.g. by adding 0x80 if message length is a multiple of 8 bits.
        message.append(0x80)
        
        // append 0 ≤ k < 512 bits '0', such that the resulting message length in bits is congruent to −64 ≡ 448 (mod 512)
        let padBytesCount = ( message.count + 8 ) % 64
        message.appendContentsOf([UInt8](count: 64 - padBytesCount, repeatedValue: 0))
        
        // append ml, in a 64-bit big-endian integer. Thus, the total length is a multiple of 512 bits.
        var mlBigEndian = ml.bigEndian
        let bytePtr = withUnsafePointer(&mlBigEndian) { UnsafeBufferPointer<UInt8>(start: UnsafePointer($0), count: sizeofValue(mlBigEndian)) }
        message.appendContentsOf(Array(bytePtr))
        
        // Process the message in successive 512-bit chunks ( 64 bytes chunks ):
        for chunkStart in 0..<message.count/64 {
            var words = [UInt32]()
            let chunk = message[chunkStart*64..<chunkStart*64+64]
            
            // break chunk into sixteen 32-bit big-endian words w[i], 0 ≤ i ≤ 15
            for i in 0...15 {
                let value = chunk.withUnsafeBufferPointer({ UnsafePointer<UInt32>($0.baseAddress + (i*4)).memory })
                words.append(value.bigEndian)
            }
            
            // Extend the sixteen 32-bit words into eighty 32-bit words:
            for i in 16...79 {
                let value = words[i-3] ^ words[i-8] ^ words[i-14] ^ words[i-16]
                words.append(rotateLeft(value, 1))
            }
            
            // Initialize hash value for this chunk:
            var a = h0
            var b = h1
            var c = h2
            var d = h3
            var e = h4
            
            for i in 0..<80 {
                var f = UInt32(0)
                var k = UInt32(0)
                switch i {
                case 0...19:
                    f = (b & c) | ((~b) & d)
                    k = 0x5A827999
                case 20...39:
                    f = b ^ c ^ d
                    k = 0x6ED9EBA1
                case 40...59:
                    f = (b & c) | (b & d) | (c & d)
                    k = 0x8F1BBCDC
                case 60...79:
                    f = b ^ c ^ d
                    k = 0xCA62C1D6
                default: break
                }
                let temp = (rotateLeft(a, 5) &+ f &+ e &+ k &+ words[i]) & 0xFFFFFFFF
                e = d
                d = c
                c = rotateLeft(b, 30)
                b = a
                a = temp
            }
            
            // Add this chunk's hash to result so far:
            h0 = ( h0 &+ a ) & 0xFFFFFFFF
            h1 = ( h1 &+ b ) & 0xFFFFFFFF
            h2 = ( h2 &+ c ) & 0xFFFFFFFF
            h3 = ( h3 &+ d ) & 0xFFFFFFFF
            h4 = ( h4 &+ e ) & 0xFFFFFFFF
        }
        
        // Produce the final hash value (big-endian) as a 160 bit number:
        var result = [UInt8]()
        
        let h0Big = h0.bigEndian
        let h1Big = h1.bigEndian
        let h2Big = h2.bigEndian
        let h3Big = h3.bigEndian
        let h4Big = h4.bigEndian
        
        result += ([UInt8(h0Big & 0xFF), UInt8((h0Big >> 8) & 0xFF), UInt8((h0Big >> 16) & 0xFF), UInt8((h0Big >> 24) & 0xFF)]);
        result += ([UInt8(h1Big & 0xFF), UInt8((h1Big >> 8) & 0xFF), UInt8((h1Big >> 16) & 0xFF), UInt8((h1Big >> 24) & 0xFF)]);
        result += ([UInt8(h2Big & 0xFF), UInt8((h2Big >> 8) & 0xFF), UInt8((h2Big >> 16) & 0xFF), UInt8((h2Big >> 24) & 0xFF)]);
        result += ([UInt8(h3Big & 0xFF), UInt8((h3Big >> 8) & 0xFF), UInt8((h3Big >> 16) & 0xFF), UInt8((h3Big >> 24) & 0xFF)]);
        result += ([UInt8(h4Big & 0xff), UInt8((h4Big >> 8) & 0xFF), UInt8((h4Big >> 16) & 0xFF), UInt8((h4Big >> 24) & 0xFF)]);
        
        return result;
    }
    
    func rotateLeft(v: UInt32, _ n: UInt32) -> UInt32 {
        return ((v << n) & 0xFFFFFFFF) | (v >> (32 - n))
    }
}
