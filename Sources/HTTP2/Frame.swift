import Foundation

/// http://httpwg.org/specs/rfc7540.html#FrameHeader
public struct Frame {
    enum FrameType: UInt8 {
        case settings = 0x04
    }
    
    var payloadLength: UInt32
    var type: FrameType
    var flags: UInt8
    
    // Most significant bit *must* be `0` as it represents a reserved bit
    var streamIdentifier: UInt32
    
    var payload: Payload
}

public final class Payload {
    var data: Data
    var bytePosition = 0
    var bitPosition = 0
    
    init(data: Data = Data()) {
        self.data = data
    }
}
