import Async
import Bits
import Foundation

/// Applies HTTP/1 chunk encoding to a stream of data
final class HTTPChunkEncodingStream: Async.Stream {
    /// See InputStream.Input
    typealias Input = ByteBuffer

    /// See OutputStream.Output
    typealias Output = ByteBuffer
    
    /// An output stream of chunk encoded data
    private let outputStream: BasicStream<Output>

    /// Create a new chunk encoding stream
    init() {
        self.outputStream = .init()
    }

    /// See OutputStream.onOutput
    func close() {
        // An empty padding chunk
        let header = Array(String.init(0, radix: 16, uppercase: true).utf8) + crlf
        /// FIXME: need to combine this
        /// FIXME: close can't just output another packet
        header.withUnsafeBufferPointer(outputStream.onInput)
        crlf.withUnsafeBufferPointer(outputStream.onInput)
        onClose()
    }

    /// See InputStream.onOutput
    func onOutput(_ outputRequest: OutputRequest) {
        outputStream.onRequestClosure = outputRequest.requestOutput
        outputStream.onCancelClosure = outputRequest.cancelOutput
    }

    
    /// See InputStream.onClose
    func onClose() {
        outputStream.onClose()
    }
    
    /// See InputStream.onInput
    func onInput(_ input: ByteBuffer) {
        // - TODO: Improve performance
        let header = Array(String.init(input.count, radix: 16, uppercase: true).utf8) + crlf
        /// FIXME: need to combine this
        header.withUnsafeBufferPointer(outputStream.onInput)
        outputStream.onInput(input)
        crlf.withUnsafeBufferPointer(outputStream.onInput)
    }
    
    /// See InputStream.onError
    func onError(_ error: Error) {
        outputStream.onError(error)
    }
    
    /// See OutputStream.output(to:)
    func output<I>(to input: I) where I : Async.InputStream, Output == I.Input {
        outputStream.output(to: input)
    }
}

private let crlf: [UInt8] = [.carriageReturn, .newLine]
