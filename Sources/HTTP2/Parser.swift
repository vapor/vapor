import Core

public final class FrameParser: Core.Stream {
    public typealias Input = ByteBuffer
    public typealias Output = Frame
    
    public var errorStream: ErrorHandler?
    public var outputStream: OutputHandler?
    
    public init() {}
    
    public func inputStream(_ input: ByteBuffer) {
        // TODO: Parse connection preface
        // TODO: parse client settings
        // TODO: send client settings
    }
}
