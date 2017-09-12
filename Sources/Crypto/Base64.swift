import Foundation
import Core

protocol Base64 : class, Core.Stream {
    static func process(_ buffer: ByteBuffer, toPointer pointer: MutableBytesPointer, capacity: Int, finish: Bool) throws -> (complete: Bool, filled: Int, consumed: Int)
    
    associatedtype Input = ByteBuffer
    associatedtype Output = ByteBuffer
    
    /// The capacity currently used in the pointer
    var currentCapacity: Int { get set }
    
    /// The total capacity of the pointer
    var allocatedCapacity: Int { get }
    
    /// The pointer for containing the base64 encoded data
    var pointer: MutableBytesPointer { get }
    
    /// The bytes that couldn't be parsed from the previous buffer
    var remainder: [UInt8] { get set }
}

extension Base64 {
    /// Processed the `input`'s `ByteBuffer` by Base64-encoding it
    ///
    /// Calls the `OutputHandler` with the Base64-encoded data
    public func inputStream(_ input: ByteBuffer) {
        var input = input
        
        func process() {
            self.remainder = []
            
            do {
                let (complete, capacity, consumed) = try Self.process(input, toPointer: pointer, capacity: allocatedCapacity, finish: false)
                self.currentCapacity = capacity
                
                // Swift doesn't recognize that Output == ByteBuffer
                let writeBuffer: Output = ByteBuffer(start: pointer, count: capacity) as! Self.Output
                
                self.outputStream?(writeBuffer)
                
                guard complete else {
                    remainder.append(contentsOf: ByteBuffer(start: input.baseAddress?.advanced(by: consumed), count: input.count &- consumed))
                    return
                }
            } catch {
                errorStream?(error)
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
    ///
    /// TODO: Implement using closable streams instead
    public func finishStream() {
        if remainder.count > 0 {
            self.inputStream(ByteBuffer(start: nil, count: 0))
        }
    }
}
