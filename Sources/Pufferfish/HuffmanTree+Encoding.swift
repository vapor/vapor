import Foundation

/// The data that can be interchanged for huffman encoded bits
public enum HuffmanAssociatedData {
    case single(UInt8)
    case many(Data)
}

/// A very primitive encodingtable.
///
/// This encodingtable does not help build a huffman tree.
public struct EncodingTable {
    public typealias Pair = (encoded: UInt64, bits: UInt8)
    
    /// A pair describing the raw data for the huffman encoded form at the same index
    var elements = [HuffmanAssociatedData]()
    
    /// A pair describing the huffman encoded form of the element at the same index
    var encoded = [Pair]()
    
    /// Appends a set of raw and encoded data to the table
    public mutating func append(raw: HuffmanAssociatedData, pair: Pair) {
        self.elements.append(raw)
        self.encoded.append(pair)
    }
    
    /// Create a new encoding table, reserving capacity
    public init(reserving size: Int = 0) {
        elements.reserveCapacity(size)
        encoded.reserveCapacity(size)
    }
}

struct IncompleteEncodingTable: Swift.Error {}

public final class HuffmanEncoder {
    /// The encoding table specification to use for encoding
    var encodingTable: EncodingTable
    
    /// An arrray that is used for an intermediate for serializing the base data `UInt64` to
    var array = [UInt8](repeating: 0, count: 8)
    
    /// Create a new huffman encoder based on an encoding table
    public init(encodingTable: EncodingTable) {
        self.encodingTable = encodingTable
    }
    
    /// Converts a single huffman encoded pair into an array buffer
    fileprivate func convert(_ base: UInt64, size: UInt8) {
        let remainder = size % 8
        let int = base.littleEndian >> remainder
        let bytes = numericCast(size / 8) as Int
        
        var index = bytes &- 1
        
        var current = 0
        
        while index >= 0 {
            array[current] = numericCast((int >> (index &* 8)) & 0xff)
            index = index &- 1
            current = current &+ 1
        }
        
        if remainder > 0 {
            let unused = (8 &- remainder)
            array[numericCast(size) / 8] = numericCast(numericCast(0xff >> unused) & base)
        }
    }
    
    /// Encoded data byte-for-byte using HuffmanCoding and an EncodingTable
    ///
    /// TODO: Support `HuffmanAssociatedData.many`
    public func encode(data input: Data) throws -> Data {
        var data = Data()
        
        // TODO: Better estimate
        data.reserveCapacity(input.count)
        
        var remainderBits: UInt8 = 0
        
        // Loops over all bytes (TODO: not-single-bytes)
        nextCharacter: for byte in input {
            // Find the byte related to the element
            // TODO: Optimize
            guard let encodedIndex = encodingTable.elements.index(where: { element in
                if case .single(let single) = element, single == byte {
                    return true
                }
                
                return false
            }) else {
                throw IncompleteEncodingTable()
            }
            
            let encoded: UInt64
            var bitLength: UInt8
            
            // Sets up the encoded form
            (encoded, bitLength) = encodingTable.encoded[encodedIndex]
            
            convert(encoded, size: bitLength)
            
            // If a previous encoding step filled in only part of the bytes
            if remainderBits > 0 {
                let alreadyFilled = 8 &- remainderBits
                
                if bitLength == remainderBits {
                    // If the buffer has exactly the needed remainder for this byte
                    data[data.count &- 1] |= array[0]
                    remainderBits = 0
                    continue nextCharacter
                } else if bitLength < remainderBits {
                    // If the buffer has less than the needed amount to complete a byte
                    remainderBits = remainderBits &- bitLength
                    data[data.count &- 1] |= array[0] << remainderBits
                    continue nextCharacter
                } else if bitLength == 8 {
                    // If the buffer has exactly 1 byte
                    data[data.count &- 1] |= array[0] >> alreadyFilled
                    
                    // Append the first non-appended bits from the first byte
                    let remainingFirstBits = 8 &- alreadyFilled
                    data.append(array[0] << remainingFirstBits)
                    
                    // Remainderbits is the same because we're adding exactly 8 bits
                    continue nextCharacter
                } else if bitLength > remainderBits && bitLength < 8 &+ remainderBits {
                    // If the buffer has enough to fill up the current byte and the next one partially and not more than that
                    if bitLength < 8 {
                        data[data.count &- 1] |= array[0] >> (bitLength &- remainderBits)
                        let nextByteSize = bitLength &- remainderBits
                        remainderBits = 8 &- nextByteSize
                        data.append(array[0] << remainderBits)
                        continue nextCharacter
                    }
                    
                    data[data.count &- 1] |= array[0] >> alreadyFilled
                    data.append(array[0] << remainderBits)
                    
                    // Append the first non-appended bits from the first byte
                    let takenFirstBits = 8 &- remainderBits
                    
                    // Leftover is the bits from the second byte that we do have
                    let secondByteBits = bitLength &- 8
                    let offset = (8 &- secondByteBits) &- takenFirstBits
                    data[data.count &- 1] |= array[1] << offset
                    
                    // Remainderbits is the bits from the second byte that we don't have
                    remainderBits = 8 &- (takenFirstBits &+ secondByteBits)
                    continue nextCharacter
                } else {
                    // If the buffer has enough data to complete the current byte and proceed with the next
                    data[data.count &- 1] |= array[0] >> alreadyFilled
                    bitLength = bitLength &- remainderBits
                    remainderBits = 0
                    
                    convert(encoded & UInt64.max >> (64 &- bitLength), size: bitLength)
                }
            }
            
            let fullBytes = bitLength / 8
            let incompleteBits = (bitLength % 8)
            remainderBits = (8 &- incompleteBits) % 8
            var index = 0
            
            for _ in 0..<fullBytes {
                data.append(array[index])
                index = index &+ 1
            }
            
            if remainderBits > 0 {
                data.append(array[index] << remainderBits)
            }
        }
        
        // If after encoding, remaining bits are still not set
        // Fill them with `1`s
        if remainderBits > 0, data.count > 0 {
            var reset: UInt8 = 0x00
            
            for _ in 0..<remainderBits {
                reset = (reset << 1) | 0b00000001
            }
            
            data[data.count &- 1] |= reset
        }
        
        return data
    }
}
