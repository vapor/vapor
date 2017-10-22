import Async

final class HTTP2StreamPool {
    var streams = [Int32: HTTP2Stream]()
    
    let serializer: FrameSerializer
    let parser: FrameParser
    
    init(serializer: FrameSerializer, parser: FrameParser) {
        self.serializer = serializer
        self.parser = parser
    }
    
    subscript(streamID: Int32) -> HTTP2Stream {
        if let stream = streams[streamID] {
            return stream
        }
        
        let stream = HTTP2Stream(
            id: streamID,
            serializer: serializer,
            parser: parser
        )
        
        self.streams[streamID] = stream
        
        return stream
    }
}

public final class HTTP2Stream: Async.Stream {
    public typealias Input = Frame
    public typealias Output = Frame
    
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    let identifier: Int32
    let serializer: FrameSerializer
    let parser: FrameParser
    var windowSize: UInt64? = nil
    
    init(id: Int32, serializer: FrameSerializer, parser: FrameParser) {
        self.identifier = id
        self.serializer = serializer
        self.parser = parser
    }
    
    public func inputStream(_ frame: Frame) {
        do {
            switch frame.type {
            case .windowUpdate:
                let update = try WindowUpdate(frame: frame, errorsTo: serializer)
                
                if let windowSize = windowSize {
                    self.windowSize = windowSize &+ numericCast(update.windowSize) as UInt64
                } else {
                    windowSize = numericCast(update.windowSize)
                }
            case .headers:
                outputStream?(frame)
            case .data:
                outputStream?(frame)
            case .pushPromise:
                assertionFailure("Unsupported")
                break
            default:
                break
            }
        } catch {
            self.errorStream?(error)
        }
    }
}
