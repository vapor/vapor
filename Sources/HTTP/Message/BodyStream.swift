import Async
import Bits

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
