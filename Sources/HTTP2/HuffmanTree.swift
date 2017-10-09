import Foundation

final class HuffmanTree {
    var table = [(data: UInt64, bitLength: UInt8)]()
    var array = [UInt8](repeating: 0, count: 8)
    
    fileprivate let bits: [UInt8] = [
        0b00000000,
        0b00000001,
        0b00000011,
        0b00000111,
        0b00001111,
        0b00011111,
        0b00111111,
        0b01111111
    ]
    
    init() {}
    
    fileprivate func convert(_ int: UInt64) {
        let int = int.littleEndian
        
        array[0] = UInt8(int & 0xff)
        array[1] = UInt8((int >> 8) & 0xff)
        array[2] = UInt8((int >> 16) & 0xff)
        array[3] = UInt8((int >> 24) & 0xff)
        array[4] = UInt8((int >> 32) & 0xff)
        array[5] = UInt8((int >> 40) & 0xff)
        array[6] = UInt8((int >> 48) & 0xff)
        array[7] = UInt8((int >> 56) & 0xff)
    }
    
    func encode(string: String) -> Data {
        var data = Data()
        var bitOffset: UInt8 = 0
        
        for character in string.utf8 {
            var (encoded, bitLength) = table[numericCast(character)]
            convert(encoded)
            
            if bitOffset > 0 {
                if bitOffset &+ bitLength < 8 {
                    bitOffset = bitOffset &+ bitLength
                } else {
                    let byte = data[data.count &- 1] & bits[numericCast(8 &- bitOffset)]
                    data[data.count &- 1] = byte &+ (array[0] & bits[numericCast(bitOffset)])
                    bitLength = bitLength &- bitOffset
                }
            } else {
                let halfBits = bitLength % 8
                data.append(numericCast(array[0] << halfBits))
                
                if bitLength > 8 {
                    bitLength -= 8
                } else {
                    bitOffset = bitLength
                }
            }
            
            
        }
        
        return data
    }
}
