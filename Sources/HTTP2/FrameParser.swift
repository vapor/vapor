import Async
import Bits

public final class FrameParser: Async.Stream {
    public typealias Input = ByteBuffer
    public typealias Output = Frame
    
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    public func inputStream(_ input: ByteBuffer) {
        
    }
}
