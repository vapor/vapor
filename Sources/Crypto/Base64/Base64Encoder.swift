import Bits
import Async
import COperatingSystem
import Foundation

/// A base64 encoder. Works as both a step in streams as well as a big-chunk encoder
///
/// Encoding a string of data:
///
///     let normalString = "test-data"
///     let base64encodedString = try Base64Encoder.encode(string: normalString)
///
/// Encoding of a stream
///
///     // pseudocode stream of incoming bytes, like a socket
///     let incoming: Stream<ByteBuffer>
///     let encoder = Base64Encoder()
///     let base64EncodedStream = incoming.stream(to: encoder)
///     // whenever the end of the base64 buffer has been reached you need mark it as "finished"
///     // this will possibly stream the final 4 bytes if the input wasn't depleted yet
///     encoder.finishStream()
///     // after finishing the stream, the encoder will return to the start and will be reuable for the next incoming data
public final class Base64Encoder: Base64 {
    /// The capacity currently used in the pointer
    public var currentCapacity = 0
    
    /// The total capacity of the pointer
    public let allocatedCapacity: Int
    
    /// The pointer for containing the base64 encoded data
    public let pointer: MutableBytesPointer

    /// base64 or base64 url
    let encoding: Base64Encoding
    
    /// Encodes the contents of the buffer into the pointer until the provided capacity has been reached
    ///
    /// - parameter buffer: The input buffer to encode
    /// - parameter pointer: The pointer to write to
    /// - parameter capacity: The capacity of the output pointer
    /// - parameter finish: If `true`, this base64 string will be completed
    /// - returns: If the base64 encoded string is complete. The capacity of the pointer used, and the amount of input bytes consumed
    public func process(_ buffer: ByteBuffer, toPointer pointer: MutableBytesPointer, capacity: Int, finish: Bool) -> (complete: Bool, filled: Int, consumed: Int) {
        // If the buffer is empty, ignore the buffer
        guard let input = buffer.baseAddress else {
            return (true, 0, 0)
        }
        
        // Sets up the three variables used for parsing
        var inputPosition = 0
        var outputPosition = 0
        var processedByte: UInt8
        
        // Fetches the byte at the given position from the encodingTable
        func byte(at pos: UInt8) -> UInt8 {
            return encoding.encodingTable[numericCast(pos)]
        }
        
        // Returns `true` the stream can continue without breaking the base64 final bytes
        func finishable() -> Bool {
            guard finish else {
                guard inputPosition &+ 3 < buffer.count else {
                    return false
                }
                
                return true
            }
            
            return true
        }
        
        // For each input chunk of at most 3 bytes, return 4 base64-encoded bytes
        while inputPosition < buffer.count, outputPosition &+ 3 < capacity, finishable() {
            defer {
                // Increase the input/output offset
                inputPosition = inputPosition &+ 3
                outputPosition = outputPosition &+ 4
            }
            
            // Split off the first byte into a UInt6
            pointer[outputPosition] = byte(at: (input[inputPosition] & 0xfc) >> 2)
            
            // Split off the first byte into a UInt2
            processedByte = (input[inputPosition] & 0x03) << 4
            
            // Executes this block if there was only 1 byte remaining
            guard inputPosition &+ 1 < buffer.count else {
                // Output the created UInt2
                pointer[outputPosition &+ 1] = byte(at: processedByte)

                if encoding.encodePadding {
                    // Append 2 '=' characters to finish off the 4-character chunk
                    pointer[outputPosition &+ 2] = 0x3d
                    pointer[outputPosition &+ 3] = 0x3d

                    // Return `true` for a finalized Base64 encoded string
                    return (true, outputPosition &+ 4, inputPosition &+ 1)
                } else {
                    // Return `true` for a finalized Base64 encoded string
                    return (true, outputPosition &+ 2, inputPosition &+ 1)
                }
            }
            
            // Combine the next first 4 bits of the second byte to create a UInt6
            processedByte |= (input[inputPosition &+ 1] & 0xf0) >> 4
            
            // Write the character associated with the new UInt6
            pointer[outputPosition &+ 1] = byte(at: processedByte)
            
            // Take the last 4 bits of the second byte to create a UInt4
            processedByte = (input[inputPosition &+ 1] & 0x0f) << 2
            
            // If there were only 2 bytes
            guard inputPosition &+ 2 < buffer.count else {
                // Write the character associated with the 4 bits number to the output
                pointer[outputPosition &+ 2] = byte(at: processedByte)

                if encoding.encodePadding {
                    // Append an '=' for padding
                    pointer[outputPosition &+ 3] = 0x3d
                    
                    // Finish off the base64 string
                    return (true, outputPosition &+ 4, inputPosition &+ 2)
                } else {
                    // Finish off the base64 string
                    return (true, outputPosition &+ 3, inputPosition &+ 2)
                }
            }
            
            // Take the first 2 bits of the last byte to create a new UInt6
            processedByte |= (input[inputPosition &+ 2] & 0xc0) >> 6
            
            // Write the new UInt6 to the output
            pointer[outputPosition &+ 2] = byte(at: processedByte)
            
            // Write the last reamining UInt6 to the output
            pointer[outputPosition &+ 3] = byte(at: input[inputPosition &+ 2] & 0x3f)
        }
        
        return (inputPosition == buffer.count, outputPosition, inputPosition)
    }
    
    /// Creates a new Base64 encoder
    ///
    /// - parameter allocatedCapacity: The expected (maximum) size of each buffer inputted into this stream
    public init(encoding: Base64Encoding, bufferCapacity: Int = 65_507) {
        self.encoding = encoding
        self.allocatedCapacity = (bufferCapacity / 3) * 4 &+ ((bufferCapacity % 3 > 0) ? 1 : 0)
        self.pointer = MutableBytesPointer.allocate(capacity: self.allocatedCapacity)
        self.pointer.initialize(to: 0, count: self.allocatedCapacity)
    }
    
    deinit {
        self.pointer.deinitialize(count: self.allocatedCapacity)
        self.pointer.deallocate(capacity: self.allocatedCapacity)
    }
    
    /// Encodes the incoming data
    ///
    /// - parameter data: The data to encode
    /// - returns: A base64 encoded string as Data
    public func encode(data bytes: Data) -> Data {
        return Array(bytes).withUnsafeBytes { input -> Data in
            guard let input = input.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return Data()
            }
            
            let pointer = MutableBytesPointer.allocate(capacity: bytes.count)
            
            defer {
                pointer.deinitialize(count: bytes.count)
                pointer.deallocate(capacity: bytes.count)
            }
            
            pointer.assign(from: input, count: bytes.count)
            return encode(buffer: ByteBuffer(start: pointer, count: bytes.count)) { buffer in
                return Data(buffer)
            }
        }
    }
    
    /// Encodes the incoming string as UTF-8 to Base64
    ///
    /// - parameter data: The string of which the UTF-8 representation will be encoded
    /// - returns: A base64 encoded string
    public func encode(string: String) -> String {
        let bytes = [UInt8](string.utf8)
        
        let pointer = MutableBytesPointer.allocate(capacity: bytes.count)
        
        pointer.assign(from: bytes, count: bytes.count)
        
        defer {
            pointer.deinitialize(count: bytes.count)
            pointer.deallocate(capacity: bytes.count)
        }
        
        return encode(buffer: ByteBuffer(start: pointer, count: bytes.count)) { buffer in
            guard let result = buffer.string() else {
                return ""
            }
            
            return result
        }
    }
    
    /// Encodes the incoming buffer into a new buffer as Base64
    ///
    /// Requires
    ///
    /// - parameter buffer: The buffer to encode
    /// - parameter handle: The closure to execute with the Base64 encoded buffer
    public func encode<T>(buffer: ByteBuffer, _ handle: ((MutableByteBuffer) throws -> (T))) rethrows -> T {
        let allocatedCapacity = ((buffer.count / 3) * 4) &+ ((buffer.count % 3 > 0) ? 4 : 0)
        
        let pointer = MutableBytesPointer.allocate(capacity: allocatedCapacity)
        pointer.initialize(to: 0, count: allocatedCapacity)
        
        let result = process(buffer, toPointer: pointer, capacity: allocatedCapacity, finish: true)
        
        defer {
            pointer.deinitialize(count: allocatedCapacity)
            pointer.deallocate(capacity: allocatedCapacity)
        }
        
        return try handle(MutableByteBuffer(start: pointer, count: result.filled))
    }
}
