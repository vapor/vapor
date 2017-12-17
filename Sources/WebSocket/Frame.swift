import COperatingSystem
import Async
import Bits

/// Frame format:
///
///  0                   1                   2                   3
///  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-------+-+-------------+-------------------------------+
/// |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
/// |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
/// |N|V|V|V|       |S|             |   (if payload len==126/127)   |
/// | |1|2|3|       |K|             |                               |
/// +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
/// |     Extended payload length continued, if payload len == 127  |
/// + - - - - - - - - - - - - - - - +-------------------------------+
/// |                               |Masking-key, if MASK set to 1  |
/// +-------------------------------+-------------------------------+
/// | Masking-key (continued)       |          Payload Data         |
/// +-------------------------------- - - - - - - - - - - - - - - - +
/// :                     Payload Data continued ...                :
/// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
/// |                     Payload Data continued ...                |
/// +---------------------------------------------------------------+
///
/// A WebSocket frame contains a payload
///
/// Interfacing with this class directly is usually not necessary and not recommended unless you know how WebSockets work.
final class Frame {
    typealias Header = (final: Bool, op: Frame.OpCode, size: UInt64, mask: [UInt8]?, consumed: Int)
    
    /// The type of payload
    enum OpCode: Byte {
        /// This message is a continuation of a previous frame and it's associated payload
        case continuation = 0x00
        
        /// This message is (the start of) a text (`String`) based payload
        case text = 0x01
        
        /// This message is (the start of) a binary payload
        case binary = 0x02
        
        /// This message is an indication of closing the connection
        case close = 0x08
        
        /// This message is a ping, it's contents must be `pong`-ed back
        case ping = 0x09
        
        /// This message is a pong and must contain the original `ping`'s contents
        case pong = 0x0a
    }
    
    /// If `true`, this is the final message in it's sequence
    let isFinal: Bool
    
    /// The type of frame (and payload)
    let opCode: OpCode
    
    /// The serialized message
    let buffer: MutableByteBuffer
    
    /// The size of the header (all the way until the start of the payload)
    var headerUntil: Int
    
    /// The length of the payload
    var payloadLength: Int {
        return buffer.count &- headerUntil
    }
    
    /// if true, this message is masked
    var isMasked: Bool {
        return self.buffer[1] & 0b10000000 == 0b10000000
    }
    
    /// The bytes used to mask the payload
    let maskBytes: [UInt8]?
    
    /// A helper for finding the buffer that contains only the payload
    fileprivate var mutablePayload: MutableByteBuffer {
        return MutableByteBuffer(start: buffer.baseAddress?.advanced(by: headerUntil), count: payloadLength)
    }
    
    /// A read-only payload buffer of this frame
    var payload: ByteBuffer {
        return ByteBuffer(start: buffer.baseAddress?.advanced(by: headerUntil), count: payloadLength)
    }
    
    deinit {
        // Deallocates the internal buffer
        buffer.dealloc()
    }
    
    /// Unmasks the data if it's masked
    func unmask() {
        guard isMasked else {
            return
        }
        
        toggleMask()
        self.buffer[1] = self.buffer[1] & 0b01111111
    }
    
    /// Masks the data if it's unmasked
    func mask() {
        guard !isMasked else {
            return
        }
        
        toggleMask()
        self.buffer[1] = self.buffer[1] | 0b10000000
    }
    
    func toggleMask() {
        guard let maskBytes = maskBytes, let pointer = mutablePayload.baseAddress else {
            return
        }
        
        // applies mask to the data and puts it into the buffer
        for i in 0..<payload.count {
            pointer[i] = pointer[i] ^ maskBytes[i % 4]
        }
    }
    
    /// Creates a new payload by referencing the original payload.
    init(op: OpCode, payload: ByteBuffer, mask: [UInt8]?, isMasked: Bool = false, isFinal: Bool = true) throws {
        if !isFinal {
            // Only binary and continuation frames can be not final
            guard op == .binary || op == .continuation else {
                throw WebSocketError(.invalidFrameParameters)
            }
        }
        
        self.opCode = op
        self.isFinal = isFinal
        
        let payloadLengthSize: Int
        let lengthByte: UInt8
        var number: [UInt8]
        
        // the amount of bytes needed for this payload
        if payload.count < 126 {
            lengthByte = UInt8(payload.count)
            payloadLengthSize = 0
            number = []
            
        // Serialize as UInt16
        } else if payload.count <= Int(UInt16.max) {
            lengthByte = 126
            payloadLengthSize = 2
            
            var length = UInt16(payload.count).littleEndian
            
            number = [UInt8](repeating: 0, count: 2)
            
            memcpy(&number, &length, 2)
            
        // Serialize as UInt64
        } else {
            lengthByte = 127
            payloadLengthSize = 8
            
            var length = UInt64(payload.count).littleEndian
            
            number = [UInt8](repeating: 0, count: 8)
            
            memcpy(&number, &length, 8)
        }
        
        // create a buffer for the entire message
        let bufferSize = 2 &+ payloadLengthSize &+ payload.count &+ (mask == nil ? 0 : 4)
        let pointer = MutableBytesPointer.allocate(capacity: bufferSize)
        
        // sets the length bytes
        pointer[1] = lengthByte
        memcpy(pointer.advanced(by: 2), number, number.count)
        
        // set final bit if needed and rawValue
        pointer.pointee = (isFinal ? 0b10000000 : 0) | op.rawValue
        
        self.buffer = MutableByteBuffer(start: pointer, count: bufferSize)
        self.headerUntil = 2 &+ payloadLengthSize &+ (mask == nil ? 0 : 4)
        
        if let mask = mask {
            // Masks must be 4 bytes
            guard mask.count == 4 else {
                self.buffer.dealloc()
                throw WebSocketError(.invalidMask)
            }
            
            // If the data is already masked
            if isMasked {
                // Set the mask bit
                pointer[1] = pointer[1] | 0b10000000
            }
            
            memcpy(pointer.advanced(by: 2 &+ payloadLengthSize), mask, 4)
        }
        
        // You can't write empty buffers
        if let baseAddress = payload.baseAddress {
            memcpy(pointer.advanced(by: headerUntil), baseAddress, payload.count)
        }
        
        self.maskBytes = mask
    }
}
