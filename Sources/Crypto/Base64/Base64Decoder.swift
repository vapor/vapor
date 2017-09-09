import Core
import libc

/// Precomputed decoding table
//fileprivate let decodeLookupTable: Data = [
//    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
//    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
//    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 62, 64, 62, 64, 63,
//    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 64, 64, 64, 64, 64, 64,
//    64, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14,
//    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 64, 64, 64, 64, 63,
//    64, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
//    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 64, 64, 64, 64, 64,
//    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
//    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
//    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
//    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
//    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
//    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
//    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
//    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
//    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
//]

import Foundation

/// the encoding table
fileprivate let encodeTable = Data("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)

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
public final class Base64Encoder : Core.Stream {
    /// Accepts byte streams
    public typealias Input = ByteBuffer
    
    /// Outputs Base64Encoded byte streams
    public typealias Output = ByteBuffer
    
    /// See `OutputStream.OutputHandler`
    public var outputStream: OutputHandler?
    
    /// See `BaseStream.Errorhandler`
    public var errorStream: ErrorHandler?
    
    /// An error that is theoretically impossible to receive.
    ///
    /// It is, however, practically possible to receive due to a bug inside the Base64Encoder
    public struct UnknownFailure : Error {}
    
    /// Encodes the contents of the buffer into the pointer until the provided capacity has been reached
    ///
    /// - parameter buffer: The input buffer to encode
    /// - parameter pointer: The pointer to write to
    /// - parameter capacity: The capacity of the output pointer
    /// - parameter finish: If `true`, this base64 string will be completed
    /// - returns: If the base64 encoded string is complete. The capacity of the pointer used, and the amount of input bytes consumed
    fileprivate static func encode(_ buffer: ByteBuffer, toPointer pointer: MutableBytesPointer, capacity: Int, finish: Bool) -> (complete: Bool, filled: Int, consumed: Int) {
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
            return encodeTable[numericCast(pos)]
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
                
                // Append 2 '=' characters to finish off the 4-character chunk
                pointer[outputPosition &+ 2] = 0x3d
                pointer[outputPosition &+ 3] = 0x3d
                
                // Return `true` for a finalized Base64 encoded string
                return (true, outputPosition &+ 4, inputPosition &+ 1)
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
                
                // Append an '=' for padding
                pointer[outputPosition &+ 3] = 0x3d
                
                // Finish off the base64 string
                return (true, outputPosition &+ 4, inputPosition &+ 2)
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
    
    /// Encodes the incoming data
    ///
    /// - parameter data: The data to encode
    /// - returns: A base64 encoded string as Data
    public static func encode(data bytes: Data) throws -> Data {
        return try Array(bytes).withUnsafeBytes { input -> Data in
            guard let input = input.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw UnknownFailure()
            }
            
            let pointer = MutableBytesPointer.allocate(capacity: bytes.count)
            
            defer {
                pointer.deinitialize(count: bytes.count)
                pointer.deallocate(capacity: bytes.count)
            }
            
            pointer.assign(from: input, count: bytes.count)
            return try encode(buffer: ByteBuffer(start: pointer, count: bytes.count)) { buffer in
                return Data(buffer)
            }
        }
    }
    
    /// Encodes the incoming string as UTF-8 to Base64
    ///
    /// - parameter data: The string of which the UTF-8 representation will be encoded
    /// - returns: A base64 encoded string
    public static func encode(string: String) throws -> String {
        let bytes = [UInt8](string.utf8)
        
        let pointer = MutableBytesPointer.allocate(capacity: bytes.count)
        
        pointer.assign(from: bytes, count: bytes.count)
        
        defer {
            pointer.deinitialize(count: bytes.count)
            pointer.deallocate(capacity: bytes.count)
        }
        
        return try encode(buffer: ByteBuffer(start: pointer, count: bytes.count)) { buffer in
            guard let result = buffer.string() else {
                throw UnknownFailure()
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
    public static func encode<T>(buffer: ByteBuffer, _ handle: ((MutableByteBuffer) throws -> (T))) throws -> T {
        let allocatedCapacity = ((buffer.count / 3) * 4) &+ ((buffer.count % 3 > 0) ? 4 : 0)
        
        let pointer = MutableBytesPointer.allocate(capacity: allocatedCapacity)
        pointer.initialize(to: 0, count: allocatedCapacity)
        
        let result = Base64Encoder.encode(buffer, toPointer: pointer, capacity: allocatedCapacity, finish: true)
        
        defer {
            pointer.deinitialize(count: allocatedCapacity)
            pointer.deallocate(capacity: allocatedCapacity)
        }
        
        guard result.complete else {
            throw UnknownFailure()
        }
        
        return try handle(MutableByteBuffer(start: pointer, count: allocatedCapacity))
    }
    
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
    public init(allocatedCapacity: Int = 65_507) {
        self.allocatedCapacity = (allocatedCapacity / 3) * 4 &+ ((allocatedCapacity % 3 > 0) ? 1 : 0)
        self.pointer = MutableBytesPointer.allocate(capacity: self.allocatedCapacity)
        self.pointer.initialize(to: 0, count: self.allocatedCapacity)
    }
    
    deinit {
        self.pointer.deinitialize(count: self.allocatedCapacity)
        self.pointer.deallocate(capacity: self.allocatedCapacity)
    }
    
    /// Processed the `input`'s `ByteBuffer` by Base64-encoding it
    ///
    /// Calls the `OutputHandler` with the Base64-encoded data
    public func inputStream(_ input: ByteBuffer) {
        var input = input
        
        func process() {
            self.remainder = []
            
            let (complete, capacity, consumed) = Base64Encoder.encode(input, toPointer: pointer, capacity: allocatedCapacity, finish: false)
            self.currentCapacity = capacity
            
            let writeBuffer = ByteBuffer(start: pointer, count: capacity)
            
            self.outputStream?(writeBuffer)
            
            guard complete else {
                remainder.append(contentsOf: ByteBuffer(start: input.baseAddress?.advanced(by: consumed), count: input.count &- consumed))
                return
            }
        }
        
        guard remainder.count == 0 else {
            let newPointer = MutableBytesPointer.allocate(capacity: remainder.count &+ input.count)
            newPointer.initialize(to: 0, count: remainder.count &+ input.count)
            
            if input.count > 0 {
                guard let inputPointer = input.baseAddress else {
                    return
                }
                
                newPointer.assign(from: remainder, count: remainder.count)
                newPointer.advanced(by: remainder.count).assign(from: inputPointer, count: input.count)
            }
            
            process()
            return
        }
        
        process()
    }
    
    /// Completes the stream, flushing all remaining bytes by encoding them
    public func finishStream() {
        if remainder.count > 0 {
            self.inputStream(ByteBuffer(start: nil, count: 0))
        }
    }
}
