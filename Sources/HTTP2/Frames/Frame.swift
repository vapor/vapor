import Bits
import Foundation

/// http://httpwg.org/specs/rfc7540.html#FrameHeader
///
/// A single HTTP/2 Frame
public final class Frame {
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
    
    /// The size of the payload data
    ///
    /// Not used beyond basic frame checks
    var payloadLength: UInt32
    
    /// The frame type
    var type: FrameType
    
    /// The flags of this frame (differs per frame type)
    var flags: UInt8
    
    // Most significant bit *must* be `0` as it represents a reserved bit
    var streamIdentifier: Int32
    
    /// The frame's payload
    ///
    /// Content differs per frame type
    var payload: Payload
    
    /// Creates a new frame
    init(type: FrameType, payload: Payload, streamID: Int32, flags: UInt8 = 0) {
        self.type = type
        self.payload = payload
        self.payloadLength = numericCast(payload.data.count)
        self.streamIdentifier = streamID
        self.flags = flags
    }
}

/// Carries the frame's payload
public final class Payload {
    var data: Data
    var bytePosition = 0
    var bitPosition = 0
    
    init(data: Data = Data()) {
        self.data = data
    }
}
