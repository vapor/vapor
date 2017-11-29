import Async
import Bits
import Foundation

/// Applies HTTP/1 chunk encoding to a stream of data
final class ChunkEncoder: Async.Stream, ClosableStream {
    typealias Input = ByteBuffer
    
    typealias Output = ByteBuffer
    
    /// An output stream of chunk encoded data
    let stream = BasicStream<Output>()
    
    /// See OutputStream.onOutput
    func close() {
        // An empty padding chunk
        self.onInput(ByteBuffer(start: nil, count: 0))
        
        stream.close()
    }
    
    /// See ClosableStream.onClose
    func onClose(_ onClose: ClosableStream) {
        stream.onClose(onClose)
    }
    
    /// See InputStream.onInput
    func onInput(_ input: ByteBuffer) {
        // - TODO: Improve performance
        let header = Array(String.init(input.count, radix: 16, uppercase: true).utf8) + crlf
        
        header.withUnsafeBufferPointer(stream.onInput)
        stream.onInput(input)
        crlf.withUnsafeBufferPointer(stream.onInput)
    }
    
    /// See InputStream.onError
    func onError(_ error: Error) {
        stream.onError(error)
    }
    
    /// See OutputStream.onOutput
    func onOutput<I>(_ input: I) where I : Async.InputStream, ChunkEncoder.Output == I.Input {
        stream.onOutput(input)
    }
}

fileprivate let crlf: [UInt8] = [.carriageReturn, .newLine]
