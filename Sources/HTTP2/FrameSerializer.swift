import Async
import Bits

public final class FrameSerializer: Async.Stream {
    public typealias Input = Frame
    public typealias Output = ByteBuffer
    
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    public func inputStream(_ input: Frame) {
        
    }
}
