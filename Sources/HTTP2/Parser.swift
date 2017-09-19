import Core
import Foundation

fileprivate let clientPreface = Data("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".utf8)

public final class FrameParser: Core.Stream {
    public typealias Input = ByteBuffer
    public typealias Output = Frame
    
    public var errorStream: ErrorHandler?
    public var outputStream: OutputHandler?
    
    public init() {}
    
    var prefaceReceived = false
    
    public func inputStream(_ input: ByteBuffer) {
        if !prefaceReceived {
            
        }
        
        // TODO: Parse connection preface
        // TODO: parse client settings
        // TODO: send client settings
        // TODO: parse client settings
        // TODO: parse frame
        // TODO: FRAME_SIZE_ERROR on too large frames
        // TODO: HPACK (header compression)
        
    }
}
