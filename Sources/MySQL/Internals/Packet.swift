import Foundation
import Async
import Bits

/// Any MySQL packet
internal class Packet {
    /// Keeps track of the mutability of the buffer so it can be deallocated
    enum Buffer {
        case mutable(MutableByteBuffer)
        case immutable(ByteBuffer)
    }
    
    // Maximum payload size
    static let maxPayloadSize: Int = 16_777_216
    
    /// The sequence ID is incremented per message
    /// This client doesn't use this
    var sequenceId: UInt8
    
    /// The payload contains the packet's data
    var payload: ByteBuffer {
        switch buffer {
        case .immutable(let buffer): return buffer
        case .mutable(let buffer): return ByteBuffer(start: buffer.baseAddress, count: buffer.count)
        }
    }
    
    var buffer: Buffer
    
    /// Creates a new packet
    init(sequenceId: UInt8, payload: ByteBuffer) {
        self.sequenceId = sequenceId
        self.buffer = .immutable(payload)
    }
    
    /// Creates a new packet
    init(sequenceId: UInt8, payload: MutableByteBuffer) {
        self.sequenceId = sequenceId
        self.buffer = .mutable(payload)
    }
    
    deinit {
        if case .mutable(let buffer) = buffer {
            // Deallocates the MySQL buffer
            buffer.baseAddress?.deallocate(capacity: buffer.count)
        }
    }
}
