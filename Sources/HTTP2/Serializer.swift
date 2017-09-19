import Core
import Dispatch

public final class FrameSerializer: Core.Stream {
    public typealias Input = Frame
    public typealias Output = DispatchData
    
    public var errorStream: ErrorHandler?
    public var outputStream: OutputHandler?
    
    public init() {}
    
    public func inputStream(_ input: Frame) {
        
    }
}
