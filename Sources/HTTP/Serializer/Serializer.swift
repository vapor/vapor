import Async
import Bits
import Dispatch
import Foundation

/// Internal Swift HTTP serializer protocol.
internal protocol Serializer: Async.Stream {
    /// The output to write to
    var outputStream: BasicStream<ByteBuffer> { get }
    
    /// A buffer used to store writes in temporarily
    var writeBuffer: MutableBytesPointer { get }
    
    /// A current data in the writeBuffer
    var writeBufferUsage: Int { get set }
    
    /// The size of the above buffer
    var writeBufferSize: Int { get }
    
    /// Writes data into the buffer
    func write(_ buffer: ByteBuffer)
    
    /// Force-flushes to the socket
    func flush()
}

extension Serializer {
    /// Flushes all remaining data on to the output stream
    func flush() {
        self.outputStream.onInput(ByteBuffer(start: writeBuffer, count: writeBufferUsage))
        self.writeBufferUsage = 0
    }
    
    /// Manages the internal buffer and uses it for building a message for more efficient stream writes
    func write(_ buffer: ByteBuffer) {
        guard let pointer = buffer.baseAddress else {
            return
        }
        
        if buffer.count + writeBufferUsage <= writeBufferSize {
            memcpy(writeBuffer.advanced(by: writeBufferUsage), pointer, buffer.count)
            writeBufferUsage += buffer.count
        } else {
            var taken = writeBufferSize - writeBufferUsage
            
            if taken > buffer.count {
                taken = buffer.count
            }
            
            memcpy(writeBuffer.advanced(by: writeBufferUsage), pointer, taken)
            
            while taken < buffer.count {
                flush()
                self.writeBufferUsage = min(buffer.count - taken, writeBufferSize)
                taken += self.writeBufferUsage
            }
        }
    }
}

extension DispatchData {
    init(_ string: String) {
        let bytes = string.withCString { pointer in
            return UnsafeRawBufferPointer(
                start: pointer,
                count: string.utf8.count
            )
        }
        self.init(bytes: bytes)
    }
}
