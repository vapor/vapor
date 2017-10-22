import Async
import Bits
import libc

public final class FrameSerializer: Async.Stream {
    public typealias Input = Frame
    public typealias Output = ByteBuffer
    
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    public func inputStream(_ input: Frame) {
        guard input.payload.data.count <= 16_777_215 else {
            errorStream?(Error(.invalidFrameReceived))
            return
        }
        
        // Update length header
        input.payloadLength = numericCast(input.payload.data.count)
        
        // header size + payload
        let messageLength = 9 + input.payload.data.count
        
        let pointer = MutableBytesPointer.allocate(capacity: messageLength)
        
        // Payload length
        pointer[0] = numericCast((input.payloadLength >> 16) & 0xff)
        pointer[1] = numericCast((input.payloadLength >> 8) & 0xff)
        pointer[2] = numericCast(input.payloadLength & 0xff)
        
        // type
        pointer[3] = input.type.rawValue
        
        // flags
        pointer[4] = input.flags
        
        pointer[5] = numericCast((input.streamIdentifier >> 24) & 0xff)
        pointer[6] = numericCast((input.streamIdentifier >> 16) & 0xff)
        pointer[7] = numericCast((input.streamIdentifier >> 8) & 0xff)
        pointer[8] = numericCast((input.streamIdentifier) & 0xff)
        
        input.payload.data.withUnsafeBytes { (payload: BytesPointer) in
            _ = memcpy(pointer.advanced(by: 9), payload, input.payload.data.count)
        }
        
        outputStream?(ByteBuffer(start: pointer, count: messageLength))
    }
}
