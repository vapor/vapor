import Async
import Bits
import Foundation

final class ChunkEncoder: Async.Stream, ClosableStream {
    typealias Input = ByteBuffer
    
    typealias Output = ByteBuffer
    
    let stream = BasicStream<Output>()
    
    func close() {
        stream.close()
    }
    
    func onClose(_ onClose: ClosableStream) {
        stream.onClose(onClose)
    }
    
    /// - TODO: Improve performance
    func onInput(_ input: ByteBuffer) {
        Data(input.count.description.utf8 + crlf).withByteBuffer(stream.onInput)
        stream.onInput(input)
        crlf.withUnsafeBufferPointer(stream.onInput)
    }
    
    func onError(_ error: Error) {
        stream.onError(error)
    }
    
    func onOutput<I>(_ input: I) where I : Async.InputStream, ChunkEncoder.Output == I.Input {
        stream.onOutput(input)
    }
}

fileprivate let crlf: [UInt8] = [.carriageReturn, .newLine]
