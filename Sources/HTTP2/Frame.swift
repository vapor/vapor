import Bits
import Foundation

/// http://httpwg.org/specs/rfc7540.html#FrameHeader
public struct Frame {
    enum FrameType: UInt8 {
        case settings = 4
    }
    
    var payloadLength: UInt32
    var type: FrameType
    var flags: UInt8
    
    // Most significant bit *must* be `0` as it represents a reserved bit
    var streamIdentifier: UInt32
    
    var payload: Payload
    
    init(type: FrameType, payload: Payload, streamID: UInt32, flags: UInt8 = 0) {
        self.type = type
        self.payload = payload
        self.payloadLength = numericCast(payload.data.count)
        self.streamIdentifier = streamID
        self.flags = flags
    }
    
    var acknowledgeSettings: Frame {
        return Frame(type: .settings, payload: Payload(data: Data()), streamID: 0, flags: 0b10000000)
    }
}

public final class Payload {
    var data: Data
    var bytePosition = 0
    var bitPosition = 0
    
    init(data: Data = Data()) {
        self.data = data
    }
}
