import Foundation
import Bits

extension BCrypt {
    /// Base64 extension for BCrypt. This is a weird base64 since instead of using
    /// /+ for the last two characters, or the urlEncoded -_, it uses /.
    struct Base64 {
        static let encodingTable : [Byte] = [
            .period, .forwardSlash, .A, .B, .C, .D, .E, .F, .G, .H, .I, .J, .K,
            .L, .M, .N, .O, .P, .Q, .R, .S, .T, .U, .V, .W, .X,
            .Y, .Z, .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k,
            .l, .m, .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x,
            .y, .z, .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine
        ]
        
        static let decodingTable : [Byte]  = [
            .max, .max, .max, .max, .max, .max, .max, .max, .max, .max,
            .max, .max, .max, .max, .max, .max, .max, .max, .max, .max,
            .max, .max, .max, .max, .max, .max, .max, .max, .max, .max,
            .max, .max, .max, .max, .max, .max, .max, .max, .max, .max,
            .max, .max, .max, .max, .max, .max,  0,  1, 54, 55,
            56, 57, 58, 59, 60, 61, 62, 63, .max, .max,
            .max, .max, .max, .max, .max,  2,  3,  4,  5,  6,
            7,  8,  9, 10, 11, 12, 13, 14, 15, 16,
            17, 18, 19, 20, 21, 22, 23, 24, 25, 26,
            27, .max, .max, .max, .max, .max, .max, 28, 29, 30,
            31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
            41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
            51, 52, 53, .max, .max, .max, .max, .max
        ]
        
        static func encode(_ bytes: Data, count: Int) -> Data {
            if bytes.count == 0 || count == 0 {
                return Data()
            }
            
            var len: Int = Int(count)
            if len > bytes.count {
                len = bytes.count
            }
            
            var offset: Int = 0
            var c1: UInt8
            var c2: UInt8
            var result = Data()
            
            while offset < len {
                c1 = bytes[offset] & 0xff
                offset += 1
                result.append(encodingTable[Int((c1 >> 2) & 0x3f)])
                c1 = (c1 & 0x03) << 4
                if offset >= len {
                    result.append(encodingTable[Int(c1 & 0x3f)])
                    break
                }
                
                c2 = bytes[offset] & 0xff
                offset += 1
                c1 |= (c2 >> 4) & 0x0f
                result.append(encodingTable[Int(c1 & 0x3f)])
                c1 = (c2 & 0x0f) << 2
                if offset >= len {
                    result.append(encodingTable[Int(c1 & 0x3f)])
                    break
                }
                
                c2 = bytes[offset] & 0xff
                offset += 1
                c1 |= (c2 >> 6) & 0x03
                result.append(encodingTable[Int(c1 & 0x3f)])
                result.append(encodingTable[Int(c2 & 0x3f)])
            }
            
            return result
        }
        
        private static func char64of(x: Byte) -> Byte {
            if x < 0 || x > 128 - 1 {
                // The character would go out of bounds of the pre-calculated array so return -1.
                return Byte.max
            }
            
            // Return the matching Base64 encoded character.
            return decodingTable[Int(x)]
        }
        
        static func decode(_ s: Data, count maxolen: Int) -> Data {
            let maxolen = Int(maxolen)
            
            var off: Int = 0
            var olen: Int = 0
            var result = Bytes(repeating: 0, count: maxolen)
            
            var c1: Byte
            var c2: Byte
            var c3: Byte
            var c4: Byte
            var o: Byte
            
            while off < s.count - 1 && olen < maxolen {
                c1 = char64of(x: s[off])
                off += 1
                c2 = char64of(x: s[off])
                off += 1
                if c1 == Byte.max || c2 == Byte.max {
                    break
                }
                
                o = c1 << 2
                o |= (c2 & 0x30) >> 4
                result[olen] = o
                olen += 1
                if olen >= maxolen || off >= s.count {
                    break
                }
                
                c3 = char64of(x: s[Int(off)])
                off += 1
                
                if c3 == Byte.max {
                    break
                }
                
                o = (c2 & 0x0f) << 4
                o |= (c3 & 0x3c) >> 2
                result[olen] = o
                olen += 1
                if olen >= maxolen || off >= s.count {
                    break
                }
                
                c4 = char64of(x: s[off])
                off += 1
                o = (c3 & 0x03) << 6
                o |= c4
                result[olen] = o
                olen += 1
            }
            
            return Data(result[0..<olen])
        }
    }
}
