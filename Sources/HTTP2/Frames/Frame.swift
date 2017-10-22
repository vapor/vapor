import Bits
import Foundation

/// http://httpwg.org/specs/rfc7540.html#FrameHeader
public struct Frame {
    enum FrameType: UInt8 {
        case data = 0
        case headers = 1
        case priority = 2
        case reset = 3
        case settings = 4
        case pushPromise = 5
        case ping = 6
        case goAway = 7
        case windowUpdate = 8
        case continuation = 9
    }
    
    var payloadLength: UInt32
    var type: FrameType
    var flags: UInt8
    
    // Most significant bit *must* be `0` as it represents a reserved bit
    var streamIdentifier: Int32
    
    var payload: Payload
    
    init(type: FrameType, payload: Payload, streamID: Int32, flags: UInt8 = 0) {
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
