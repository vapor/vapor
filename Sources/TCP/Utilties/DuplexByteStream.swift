import Async
import Bits

//public final class DuplexByteStream: Async.Stream {
//    public typealias Input = ByteBuffer
//    public typealias Output = ByteBuffer
//    
//    let stream = BasicStream<ByteBuffer>()
//    let send: ((Input) -> ())
//    
//    public init<S: Stream>(_ s: S) where S.Input == ByteBuffer, S.Output == ByteBuffer {
//        s.stream(to: stream)
//        self.send = s.onInput
//    }
//    
//    public func onInput(_ input: Input) {
//        self.send(input)
//    }
//    
//    public func onError(_ error: Error) {
//        stream.onError(error)
//    }
//    
//    public func onOutput<I>(_ input: I) where I : InputStream, DuplexByteStream.Output == I.Input {
//        stream.onOutput(input)
//    }
//    
//    public func close() {
//        stream.close()
//    }
//    
//    public func onClose(_ onClose: ClosableStream) {
//        stream.onClose(onClose)
//    }
//}

