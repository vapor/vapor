import libc
import Async
import Bits

/// Serializes frames to binary
final class FrameSerializer : Async.Stream {
    typealias Input = Frame
    
    typealias Output = ByteBuffer
    
    var outputStream: OutputHandler?
    var errorStream: ErrorHandler?
    
    func inputStream(_ input: Frame) {
        // masks the data if needed
        if mask {
            input.mask()
        } else {
            input.unmask()
        }
        
        outputStream?(ByteBuffer(start: input.buffer.baseAddress, count: input.buffer.count))
    }
    
    let mask: Bool
    
    init(masking: Bool) {
        self.mask = masking
    }
}

/// Generates a random mask for client sockets
func randomMask() -> [UInt8] {
    var buffer: [UInt8] = [0,0,0,0]
    
    var number: UInt32
    
    #if os(Linux)
        number = numericCast(libc.random() % Int(UInt32.max))
    #else
        number = arc4random_uniform(UInt32.max)
    #endif
    
    memcpy(&buffer, &number, 4)
    
    return buffer
}
