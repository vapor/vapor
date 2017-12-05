import Async
import Bits
import Foundation

/// Applies HTTP/1 chunk encoding to a stream of data
final class ChunkEncoder: Async.Stream, ClosableStream {
    typealias Input = ByteBuffer
    
    typealias Output = ByteBuffer
    
    /// An output stream of chunk encoded data
    let outputStream = BasicStream<Output>()
    
    /// See OutputStream.onOutput
    func close() {
        // An empty padding chunk
        let header = Array(String.init(0, radix: 16, uppercase: true).utf8) + crlf
        header.withUnsafeBufferPointer(outputStream.onInput)
        crlf.withUnsafeBufferPointer(outputStream.onInput)
        outputStream.close()
    }
    
    /// See ClosableStream.onClose
    func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }
    
    /// See InputStream.onInput
    func onInput(_ input: ByteBuffer) {
        // - TODO: Improve performance
        let header = Array(String.init(input.count, radix: 16, uppercase: true).utf8) + crlf
        
        header.withUnsafeBufferPointer(outputStream.onInput)
        outputStream.onInput(input)
        crlf.withUnsafeBufferPointer(outputStream.onInput)
    }
    
    /// See InputStream.onError
    func onError(_ error: Error) {
        outputStream.onError(error)
    }
    
    /// See OutputStream.onOutput
    func onOutput<I>(_ input: I) where I : Async.InputStream, ChunkEncoder.Output == I.Input {
        outputStream.onOutput(input)
    }
}

fileprivate let crlf: [UInt8] = [.carriageReturn, .newLine]
