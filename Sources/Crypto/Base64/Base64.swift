import Foundation
import Async
import Bits


/// the encoding table
fileprivate let encodeTable_base64 = Data("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
fileprivate let encodeTable_base64url = Data("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".utf8)

/// Precomputed decoding table, supports both base64url and base64
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

/// Supported encoding methods
public enum Base64Encoding {
    case base64url
    case base64
}

extension Base64Encoding {
    /// The encoding table for this encoding
    internal var encodingTable: Data {
        switch self {
        case .base64: return encodeTable_base64
        case .base64url: return encodeTable_base64url
        }
    }

    /// The decoding table for this encoding
    internal var decodingTable: Bytes {
        return decodeTable
    }
}

protocol Base64: Async.Stream {
    func process(
        _ buffer: ByteBuffer,
        toPointer pointer: MutableBytesPointer,
        capacity: Int,
        finish: Bool
    ) throws -> (complete: Bool, filled: Int, consumed: Int)
    
    init(encoding: Base64Encoding, bufferCapacity: Int)
    
    /// The capacity currently used in the pointer
    var currentCapacity: Int { get set }
    
    /// The total capacity of the pointer
    var allocatedCapacity: Int { get }
    
    /// The pointer for containing the base64 encoded data
    var pointer: MutableBytesPointer { get }
    
    /// The bytes that couldn't be parsed from the previous buffer
    var remainder: Data { get set }

    /// Use a basic stream to easily implement our output stream.
    var outputStream: BasicStream<ByteBuffer> { get }
}

extension Base64 {
    /// Creates a Base64 coder with default buffer size and encoding
    public init() {
        self.init(encoding: .base64)
    }

    /// Creates a base64 coder with supplied encoding and default buffer size
    public init(encoding: Base64Encoding) {
        self.init(encoding: encoding, bufferCapacity: 65_536)
    }

    /// Creates a base64 coder with default encoding and supplied buffer size
    public init(bufferCapacity: Int) {
        self.init(encoding: .base64, bufferCapacity: bufferCapacity)
    }

    /// Accepts Base64 encoded byte streams
    public typealias Input = ByteBuffer

    /// Outputs  byte streams
    public typealias Output = ByteBuffer
    
    /// Processed the `input`'s `ByteBuffer` by Base64-encoding it
    ///
    /// Calls the `OutputHandler` with the Base64-encoded data
    public func onInput(_ input: ByteBuffer) {
        var input = input
        
        // Continues processing the `ByteBuffer` at `input`
        func process() {
            self.remainder = Data()
            
            do {
                // Process the bytes into the local buffer `pointer`
                let (complete, capacity, consumed) = try self.process(input, toPointer: pointer, capacity: allocatedCapacity, finish: false)
                self.currentCapacity = capacity
                
                // Swift doesn't recognize that Output == ByteBuffer
                // Create a buffer referencing the ouput pointer and the outputted capacity
                let writeBuffer = ByteBuffer(start: pointer, count: capacity)
                
                // Write the output buffer to the output stream
                outputStream.onInput(writeBuffer)
                
                // If processing is complete
                guard complete else {
                    // Append any unprocessed data to the remainder storage
                    remainder.append(
                        contentsOf: ByteBuffer(
                            start: input.baseAddress?.advanced(by: consumed),
                            count: input.count &- consumed
                        )
                    )
                    return
                }
            } catch {
                self.onError(error)
            }
        }
        
        // If the remainder from previous processing attempts is not empty
        guard remainder.count == 0 else {
            // Create a new buffer for the input + the remainder
            let newPointerLength = remainder.count &+ input.count
            let newPointer = MutableBytesPointer.allocate(capacity: newPointerLength)
            newPointer.initialize(to: 0, count: newPointerLength)
            
            defer {
                newPointer.deinitialize(count: newPointerLength)
                newPointer.deallocate(capacity: newPointerLength)
            }
            
            // Set the remainder
            remainder.withUnsafeBytes { pointer in
                newPointer.assign(from: pointer, count: remainder.count)
            }
            
            // Appends the input
            if input.count > 0, let inputPointer = input.baseAddress {
                newPointer.advanced(by: remainder.count).assign(from: inputPointer, count: input.count)
            }
            
            input = ByteBuffer(start: newPointer, count: newPointerLength)
            
            // Processes this buffer
            process()
            return
        }
        
        process()
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, ByteBuffer == I.Input {
        outputStream.onOutput(input)
    }

    /// See ClosableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }

    /// Completes the stream, flushing all remaining bytes by encoding them
    ///
    /// Any data after this will reopen the stream
    public func close() {
        if remainder.count > 0 {
            remainder.withUnsafeBytes { (pointer: BytesPointer) in
                do {
                    let buffer = ByteBuffer(start: pointer, count: remainder.count)
                    
                    /// Process the remainder
                    let (_, capacity, _) = try process(buffer, toPointer: self.pointer, capacity: allocatedCapacity, finish: true)
                    
                    /// Create an output buffer (having to force cast an always-success case)
                    let writeBuffer = ByteBuffer(start: self.pointer, count: capacity)
                    
                    // Write the output buffer to the output stream
                    self.outputStream.onInput(writeBuffer)
                } catch {
                    self.onError(error)
                }
            }
        }
        
        outputStream.close()
    }
}
