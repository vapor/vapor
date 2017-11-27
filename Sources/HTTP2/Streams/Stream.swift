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
    /// The window size keeps track of the maximum amount of data that can still be sent
    var windowSize: UInt64? = nil
    
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
    
    let identifier: Int32
    let context: ConnectionContext
    var windowSize: UInt64? = nil
    
    private let stream = BasicStream<Output>()
    
    init(id: Int32, context: ConnectionContext) {
        self.identifier = id
        self.context = context
    }
    
    public func close() {
        stream.close()
    }
    
    public func onClose(_ onClose: ClosableStream) {
        stream.onClose(onClose)
    }
    
    public func onOutput<I>(_ input: I) where I : InputStream, HTTP2Stream.Output == I.Input {
        stream.onOutput(input)
    }
    
    public func onInput(_ frame: Frame) {
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
                stream.onInput(frame)
            case .data:
                stream.onInput(frame)
            case .reset:
                throw HTTP2Error(.clientError)
            case .pushPromise:
                assertionFailure("Unsupported")
                break
            default:
                break
            }
        } catch {
            self.onError(error)
        }
    }
    
    public func onError(_ error: Error) {
        stream.onError(error)
    }
    
}
