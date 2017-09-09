import Foundation
import Core

/// Precomputed decoding table
fileprivate let decodeTable: [UInt8] = [
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 62, 64, 62, 64, 63,
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 64, 64, 64, 64, 64, 64,
    64, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14,
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 64, 64, 64, 64, 63,
    64, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
]

public final class Base64Decoder: Base64 {
    /// Accepts Base64 encoded byte streams
    public typealias Input = ByteBuffer
    
    /// Outputs  byte streams
    public typealias Output = ByteBuffer
    
    /// See `OutputStream.OutputHandler`
    public var outputStream: OutputHandler?
    
    /// See `BaseStream.Errorhandler`
    public var errorStream: ErrorHandler?
    
    /// The capacity currently used in the pointer
    var currentCapacity = 0
    
    /// The total capacity of the pointer
    let allocatedCapacity: Int
    
    /// The pointer for containing the base64 encoded data
    let pointer: MutableBytesPointer
    
    /// The bytes that couldn't be parsed from the previous buffer
    var remainder = [UInt8]()
    
    /// Creates a new Base64 encoder
    ///
    /// - parameter allocatedCapacity: The expected (maximum) size of each buffer inputted into this stream
    public init(decodedCapacity: Int = 65_507) {
        self.allocatedCapacity = (decodedCapacity / 3) * 4 &+ ((decodedCapacity % 3 > 0) ? 1 : 0)
        self.pointer = MutableBytesPointer.allocate(capacity: self.allocatedCapacity)
        self.pointer.initialize(to: 0, count: self.allocatedCapacity)
    }
    
    deinit {
        self.pointer.deinitialize(count: self.allocatedCapacity)
        self.pointer.deallocate(capacity: self.allocatedCapacity)
    }
    
    
    /// Decodes the contents of the buffer into the pointer until the provided capacity has been reached
    ///
    /// - parameter buffer: The input buffer to encode
    /// - parameter pointer: The pointer to write to
    /// - parameter capacity: The capacity of the output pointer
    /// - parameter finish: If `true`, this base64 reached the end of it's stream
    /// - returns: If the base64 processing data is complete. The capacity of the pointer used, and the amount of input bytes consumed
    static func process(_ buffer: ByteBuffer, toPointer pointer: MutableBytesPointer, capacity: Int, finish: Bool) throws -> (complete: Bool, filled: Int, consumed: Int) {
        guard let input = buffer.baseAddress else {
            return (true, 0, 0)
        }
        
        // Sets up the three variables used for parsing
        var inputPosition = 0
        var outputPosition = 0
        var processedByte: UInt8
        
        // Returns `true` the stream can continue without breaking the base64 final bytes
        func finishable() -> Bool {
            guard finish else {
                guard inputPosition &+ 4 < buffer.count else {
                    return false
                }
                
                return true
            }
            
            return true
        }
        
        // For each input chunk of at most 4 base64-encoded bytes, return 3 decoded bytes
        while inputPosition &+ 1 < buffer.count, outputPosition < capacity, finishable() {
            defer {
                inputPosition = inputPosition &+ 4
                outputPosition = outputPosition &+ 3
            }
            
            // Decode the characters back to a byte
            let input0 = decodeTable[numericCast(buffer[inputPosition])]
            let input1 = decodeTable[numericCast(buffer[inputPosition &+ 1])]
            
            // The bytes cannot be 64 or greater, that would make it an invalid base64 integer
            guard input0 < 64, input1 < 64 else {
                throw InvalidBase64()
            }
            
            pointer[outputPosition] = input0 << 2 | input1 >> 4
            
            guard inputPosition &+ 2 < buffer.count, outputPosition &+ 1 < capacity, buffer[inputPosition &+ 2] != 0x3d else {
                // Return `true` for a finalized Base64 encoded string
                return (true, outputPosition &+ 1, inputPosition &+ 2)
            }
            
            let input2 = decodeTable[numericCast(buffer[inputPosition &+ 2])]
            
            // The byte cannot be 64 or greater, that would make it an invalid base64 integer
            guard input2 < 64 else {
                throw InvalidBase64()
            }
            
            pointer[outputPosition &+ 1] = input1 << 4 | input2 >> 2
            
            guard inputPosition &+ 3 < buffer.count, outputPosition &+ 2 < capacity, buffer[inputPosition &+ 3] != 0x3d else {
                // Return `true` for a finalized Base64 encoded string
                return (true, outputPosition &+ 2, inputPosition &+ 3)
            }
            
            let input3 = decodeTable[numericCast(buffer[inputPosition &+ 3])]
            
            // The byte cannot be 64 or greater, that would make it an invalid base64 integer
            guard input3 < 64 else {
                throw InvalidBase64()
            }
            
            pointer[outputPosition &+ 2] = input2 << 6 | input3
        }
        
        // Return `true` for a finalized Base64 encoded string
        return (inputPosition == buffer.count, outputPosition, inputPosition)
    }
    
    /// Decodes the incoming base64 string
    ///
    /// - parameter data: The string data to decode
    /// - returns: A Data decoded from the inputted string
    public static func decode(data bytes: Data) throws -> Data {
        return try Array(bytes).withUnsafeBytes { input -> Data in
            guard let input = input.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return Data()
            }
            
            let pointer = MutableBytesPointer.allocate(capacity: bytes.count)
            
            defer {
                pointer.deinitialize(count: bytes.count)
                pointer.deallocate(capacity: bytes.count)
            }
            
            pointer.assign(from: input, count: bytes.count)
            return try decode(buffer: ByteBuffer(start: pointer, count: bytes.count)) { buffer in
                return Data(buffer)
            }
        }
    }
    
    /// Decodes the incoming string as UTF-8 from Base64
    ///
    /// - parameter data: The string data to decode
    /// - returns: A Data decoded from the inputted string
    public static func decode(string: String) throws -> Data {
        let bytes = [UInt8](string.utf8)
        
        let pointer = MutableBytesPointer.allocate(capacity: bytes.count)
        
        pointer.assign(from: bytes, count: bytes.count)
        
        defer {
            pointer.deinitialize(count: bytes.count)
            pointer.deallocate(capacity: bytes.count)
        }
        
        return try decode(buffer: ByteBuffer(start: pointer, count: bytes.count)) { buffer in
            return Data(buffer)
        }
    }
    
    /// Encodes the incoming buffer into a new buffer as Base64
    ///
    /// Requires
    ///
    /// - parameter buffer: The buffer to encode
    /// - parameter handle: The closure to execute with the Base64 encoded buffer
    public static func decode<T>(buffer: ByteBuffer, _ handle: ((MutableByteBuffer) throws -> (T))) throws -> T {
        let allocatedCapacity = ((buffer.count / 4) * 3) &+ ((buffer.count % 4 > 0) ? 3 : 0)
        
        let pointer = MutableBytesPointer.allocate(capacity: allocatedCapacity)
        pointer.initialize(to: 0, count: allocatedCapacity)
        
        let result = try Base64Decoder.process(buffer, toPointer: pointer, capacity: allocatedCapacity, finish: true)
        
        defer {
            pointer.deinitialize(count: allocatedCapacity)
            pointer.deallocate(capacity: allocatedCapacity)
        }
        
        return try handle(MutableByteBuffer(start: pointer, count: result.filled))
    }
}

struct InvalidBase64: Error {}
