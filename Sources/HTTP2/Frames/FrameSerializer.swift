import Async
import Bits
import libc

/// Serializes input frames and outputs them
final class FrameSerializer: Async.Stream {
    /// See `InputStream.Input`
    typealias Input = Frame
    
    /// See `OutputStream.Output`
    typealias Output = ByteBuffer
    
    /// The maximum size per frame
    var maxLength: UInt32
    
    let stream = BasicStream<Output>()
    
    init(maxLength: UInt32) {
        self.maxLength = maxLength
    }
    
    /// Serializes a frame
    func onInput(_ input: Frame) {
        // the payload must be a valid length
        guard input.payload.data.count <= 16_777_215 && input.payload.data.count + 9 < numericCast(maxLength) else {
            onError(HTTP2Error(.invalidFrameReceived))
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
        
        // Stream ID
        pointer[5] = numericCast((input.streamIdentifier >> 24) & 0xff)
        pointer[6] = numericCast((input.streamIdentifier >> 16) & 0xff)
        pointer[7] = numericCast((input.streamIdentifier >> 8) & 0xff)
        pointer[8] = numericCast((input.streamIdentifier) & 0xff)
        
        // Payload
        input.payload.data.withUnsafeBytes { (payload: BytesPointer) in
            _ = memcpy(pointer.advanced(by: 9), payload, input.payload.data.count)
        }
        
        stream.onInput(ByteBuffer(start: pointer, count: messageLength))
    }
    
    func onOutput<I>(_ input: I) where I : InputStream, FrameSerializer.Output == I.Input {
        stream.onOutput(input)
    }
    
    func onError(_ error: Error) {
        stream.onError(error)
    }
    
    func close() {
        stream.close()
    }
    
    func onClose(_ onClose: ClosableStream) {
        stream.onClose(onClose)
    }
}
