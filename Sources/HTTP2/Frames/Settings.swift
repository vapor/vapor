import Bits
import Foundation

/// http://httpwg.org/specs/rfc7540.html#SETTINGS
///
/// The settings of a HTTP2 client or peer
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
    
    /// Updates the settings by a HTTP2 settings specification
    public mutating func update(to frame: Frame) throws {
        guard frame.payload.data.count % 6 == 0 else {
            throw HTTP2Error(.invalidSettingsFrame(frame))
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
                        throw HTTP2Error(.invalidSettingsFrame(frame))
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
    
    /// Returns these settings serialized as a frame
    var frame: Frame {
        var payloadData = Data()
        
        payloadData.append(value: self.headerTableSize, forId: 0x01)
        payloadData.append(value: self.pushEnabled ? 1 : 0, forId: 0x02)
        
        if let maxConcurrentStreams = maxConcurrentStreams {
            payloadData.append(value: maxConcurrentStreams, forId: 0x03)
        }
        
        payloadData.append(value: self.maxInitialWindowSize, forId: 0x04)
        payloadData.append(value: self.maxFrameSize, forId: 0x05)
        
        if let maxHeaderListSize = maxHeaderListSize {
            payloadData.append(value: maxHeaderListSize, forId: 0x06)
        }
        
        let payload = Payload(data: payloadData)
        
        return Frame(type: .settings, payload: payload, streamID: 0)
    }
    
    static var acknowledgeFrame: Frame {
        return Frame(type: .settings, payload: Payload(), streamID: 0, flags: 0x01)
    }
}

fileprivate extension Data {
    /// Appends a id-value pair for a HTTP/2 setting
    mutating func append(value: UInt32, forId: UInt16) {
        self.append(contentsOf: [
            numericCast((forId >> 8) & 0xff),
            numericCast((forId) & 0xff),
            numericCast((value >> 24) & 0xff),
            numericCast((value >> 16) & 0xff),
            numericCast((value >> 8) & 0xff),
            numericCast((value) & 0xff),
        ])
    }
}
