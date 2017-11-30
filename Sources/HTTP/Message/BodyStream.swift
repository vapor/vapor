import Async
import Bits

/// A stream of Bytes used for HTTP bodies
///
/// In HTTP/1 this becomes chunk encoded data
public final class BodyStream: Async.Stream, ClosableStream {
    public typealias Input = ByteBuffer
    public typealias Output = ByteBuffer
    
    let stream = BasicStream<ByteBuffer>()
    
    public func onInput(_ input: ByteBuffer) {
        stream.onInput(input)
    }
    
    public func onError(_ error: Error) {
        stream.onError(error)
    }
    
    public func onOutput<I>(_ input: I) where I : InputStream, BodyStream.Output == I.Input {
        stream.onOutput(input)
    }
    
    public func close() {
        stream.close()
    }
    
    public func onClose(_ onClose: ClosableStream) {
        stream.onClose(onClose)
    }
    
    public init() {}
}
