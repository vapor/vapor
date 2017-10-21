import Bits
import Foundation

/// http://httpwg.org/specs/rfc7540.html#SETTINGS
public struct HTTP2Settings {
    public var headerTableSize: UInt32 = 4096
    public var pushEnabled = true
    
    /// 0 concurrent streams means no more opening streams
    /// nil is unlimited
    public var maxConcurrentStreams: UInt32? = nil
    public var maxInitialWindowSize: UInt32 = 65_535
    public var maxFrameSize: UInt32 = 16_384
    
    /// max 16_777_215
    /// nil is unlimited
    public var maxHeaderListSize: UInt32? = nil
    
    public init() {}
    
    public mutating func update(to frame: Frame) throws {
        guard frame.payload.data.count % 6 == 0 else {
            throw Error(.invalidSettingsFrame(frame))
        }
        
        try frame.payload.data.withUnsafeBytes { (pointer: BytesPointer) in
            var pointer = pointer
            
            for _ in 0..<frame.payload.data.count / 6 {
                let identifier = pointer.withMemoryRebound(to: UInt16.self, capacity: 1, { $0.pointee })
                let value = pointer.advanced(by: 2).withMemoryRebound(to: UInt32.self, capacity: 1, { $0.pointee })
                
                switch identifier {
                case 0x01:
                    self.headerTableSize = value
                case 0x02:
                    guard value <= 1 else {
                        throw Error(.invalidSettingsFrame(frame))
                    }
                    
                    self.pushEnabled = value == 1
                case 0x03:
                    self.maxConcurrentStreams = value
                case 0x04:
                    self.maxInitialWindowSize = value
                case 0x05:
                    self.maxFrameSize = value
                case 0x06:
                    self.maxHeaderListSize = value
                default:
                    // Ignore unknown settings
                    break
                }
                
                pointer = pointer.advanced(by: 6)
            }
        }
    }
    
    var frame: Frame {
        let payloadData = Data()
        let payload = Payload(data: payloadData)
        
        return Frame(type: .settings, payload: payload, streamID: 0)
    }
    
    static var acknowledgeFrame: Frame {
        return Frame(type: .settings, payload: Payload(), streamID: 0, flags: 0x01)
    }
}
