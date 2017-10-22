import Async

final class HTTP2StreamPool {
    var streams = [Int32: HTTP2Stream]()
    
    let context: ConnectionContext
    
    init(context: ConnectionContext) {
        self.context = context
    }
    
    subscript(streamID: Int32) -> HTTP2Stream {
        if let stream = streams[streamID] {
            return stream
        }
        
        let stream = HTTP2Stream(
            id: streamID,
            context: context
        )
        
        self.streams[streamID] = stream
        
        return stream
    }
}

public final class ConnectionContext {
    let serializer: FrameSerializer
    let parser: FrameParser
    let remoteHeaders = HPACKEncoder()
    let localHeaders = HPACKDecoder()
    
    init(parser: FrameParser, serializer: FrameSerializer) {
        self.parser = parser
        self.serializer = serializer
    }
}

public final class HTTP2Stream: Async.Stream {
    public typealias Input = Frame
    public typealias Output = Frame
    
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    let identifier: Int32
    let context: ConnectionContext
    var windowSize: UInt64? = nil
    
    init(id: Int32, context: ConnectionContext) {
        self.identifier = id
        self.context = context
    }
    
    public func close() {
        errorStream?(Error(.clientError))
    }
    
    public func inputStream(_ frame: Frame) {
        do {
            switch frame.type {
            case .windowUpdate:
                let update = try WindowUpdate(frame: frame, errorsTo: context.serializer)
                
                if let windowSize = windowSize {
                    self.windowSize = windowSize &+ numericCast(update.windowSize) as UInt64
                } else {
                    windowSize = numericCast(update.windowSize)
                }
            case .headers:
                outputStream?(frame)
            case .data:
                outputStream?(frame)
            case .reset:
                throw Error(.clientError)
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
