import Foundation
import Async
import Bits

internal class Packet {
    // Maximum payload size
    static let maxPayloadSize: Int = 16_777_216
    
    var sequenceId: UInt8
    var payload: MutableByteBuffer
    
    init(sequenceId: UInt8, payload: MutableByteBuffer) {
        self.sequenceId = sequenceId
        self.payload = payload
    }
    
    deinit {
        payload.baseAddress?.deallocate(capacity: payload.count)
    }
}
