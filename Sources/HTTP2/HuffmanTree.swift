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
        
        nextCharacter: for character in string.utf8 {
            let (encoded, bitLength) = table[numericCast(character)]
            convert(encoded)
            var index = 0
            var processed: UInt8 = 0
            
            while processed < bitLength {
                if bitOffset > 0 {
                    // Bits not yet written
                    let unprocessed = (bitLength &- processed)
                    
                    // If we can't full up a full byte
                    if bitOffset &+ unprocessed < 8 {
                        let bitStartIndex = processed % 8
                        let omittedBits = 8 &- bitStartIndex
                        
                        let newByte = (array[index] << omittedBits) >> omittedBits
                        data[data.count &- 1] |= newByte
                        
                        bitOffset = bitOffset &+ unprocessed
                        continue nextCharacter
                    } else {
                        // Take enough to fill up a byte
                        let take = 8 &- bitOffset
                        
                        let byte = (array[index] << bitOffset) >> bitOffset
                        data[data.count &- 1] |= byte
                        
                        processed = processed &+ take
                        bitOffset = 0
                    }
                } else {
                    defer { processed = processed &+ 8 }
                    
                    let unprocessed = (bitLength &- processed)
                    let fullBytes = unprocessed / 8
                    let remainderBits = unprocessed % 8
                    
                    for _ in 0..<fullBytes {
                        data.append(array[index])
                        index = index &+ 1
                    }
                    
                    if remainderBits > 0 {
                        data.append(array[index] << (8 &- remainderBits))
                    }
                    
                    bitOffset = remainderBits
                    
                    continue nextCharacter
                }
            }
        }
        
        if bitOffset > 0, data.count > 0 {
            var reset: UInt8 = 0x00
            
            for _ in 0..<8 {
                reset = (reset << 1) | 0b00000001
            }
            
            data[data.count &- 1] &= reset
        }
        
        return data
    }
}
