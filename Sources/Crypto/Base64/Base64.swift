import Foundation
import Async
import Bits

protocol Base64: Async.Stream, ClosableStream {
    static func process(_ buffer: ByteBuffer, toPointer pointer: MutableBytesPointer, capacity: Int, finish: Bool) throws -> (complete: Bool, filled: Int, consumed: Int)
    
    associatedtype Input = ByteBuffer
    associatedtype Output = ByteBuffer
    
    init(bufferCapacity: Int)
    
    /// The capacity currently used in the pointer
    var currentCapacity: Int { get set }
    
    /// The total capacity of the pointer
    var allocatedCapacity: Int { get }
    
    /// The pointer for containing the base64 encoded data
    var pointer: MutableBytesPointer { get }
    
    /// The bytes that couldn't be parsed from the previous buffer
    var remainder: Data { get set }
}

extension Base64 {
    /// Transforms a binary until stream depending on the Base64 mode (encoding/decoding) to the en/decoded variant.
    ///
    /// [For more information, see the documentation](https://docs.vapor.codes/3.0/crypto/base64/#transforming-binary-streams)
    public static func transforming<ByteStream: Async.OutputStream>(_ input: ByteStream) -> Self where ByteStream.Output == ByteBuffer {
        let stream = Self.init(bufferCapacity: 65_507)
        
        if let input = input as? ClosableStream {
            input.onClose = {
                stream.close()
            }
        }
        
        input.drain(stream.inputStream)
        
        return stream
    }
    
    /// Processed the `input`'s `ByteBuffer` by Base64-encoding it
    ///
    /// Calls the `OutputHandler` with the Base64-encoded data
    public func inputStream(_ input: ByteBuffer) {
        var input = input
        
        // Continues processing the `ByteBuffer` at `input`
        func process() {
            self.remainder = Data()
            
            do {
                // Process the bytes into the local buffer `pointer`
                let (complete, capacity, consumed) = try Self.process(input, toPointer: pointer, capacity: allocatedCapacity, finish: false)
                self.currentCapacity = capacity
                
                // Swift doesn't recognize that Output == ByteBuffer
                // Create a buffer referencing the ouput pointer and the outputted capacity
                let writeBuffer: Output = ByteBuffer(start: pointer, count: capacity) as! Self.Output
                
                // Write the output buffer to the output stream
                output(writeBuffer)
                
                // If processing is complete
                guard complete else {
                    // Append any unprocessed data to the remainder storage
                    remainder.append(contentsOf: ByteBuffer(start: input.baseAddress?.advanced(by: consumed), count: input.count &- consumed))
                    return
                }
            } catch {
                errorStream?(error)
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
    
    /// Completes the stream, flushing all remaining bytes by encoding them
    ///
    /// Any data after this will reopen the stream
    public func close() {
        if remainder.count > 0 {
            remainder.withUnsafeBytes { (pointer: BytesPointer) in
                do {
                    let buffer = ByteBuffer(start: pointer, count: remainder.count)
                    
                    /// Process the remainder
                    let (_, capacity, _) = try Self.process(buffer, toPointer: self.pointer, capacity: allocatedCapacity, finish: true)
                    
                    /// Create an output buffer (having to force cast an always-success case)
                    let writeBuffer: Output = ByteBuffer(start: self.pointer, count: capacity) as! Self.Output
                    
                    // Write the output buffer to the output stream
                    self.output(writeBuffer)
                } catch {
                    self.errorStream?(error)
                }
            }
        }
        
        self.onClose?()
    }
}
