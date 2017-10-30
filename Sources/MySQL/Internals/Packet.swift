import Foundation
import Async
import Bits

/// Any MySQL packet
internal class Packet {
    // Maximum payload size
    static let maxPayloadSize: Int = 16_777_216
    
    /// The sequence ID is incremented per message
    /// This client doesn't use this
    var sequenceId: UInt8
    
    /// The payload contains the packet's data
    var payload: MutableByteBuffer
    
    /// Creates a new packet
    init(sequenceId: UInt8, payload: MutableByteBuffer) {
        self.sequenceId = sequenceId
        self.payload = payload
    }
    
    deinit {
        // Deallocates the MySQL buffer
        payload.baseAddress?.deallocate(capacity: payload.count)
    }
}
