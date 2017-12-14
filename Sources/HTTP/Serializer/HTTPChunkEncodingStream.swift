import Async
import Bits
import Foundation

/// Applies HTTP/1 chunk encoding to a stream of data
final class HTTPChunkEncodingStream: Async.Stream, OutputRequest {
    /// See InputStream.Input
    typealias Input = ByteBuffer

    /// See OutputStream.Output
    typealias Output = ByteBuffer

    /// Current upstream output request
    /// This should be called when more output is desired.
    private var upstream: OutputRequest?

    /// Remaining requested output
    private var remainingOutputRequested: UInt

    /// Capable of handling an encoded chunk
    typealias ChunkHandler = (ByteBuffer) -> ()

    /// Closure for handling encoded chunks
    var chunkHandler: ChunkHandler?

    /// Capable of handling a close event
    typealias CloseHandler = () -> ()

    /// Closure for handling a close event
    var closeHandler: CloseHandler?

    /// Create a new chunk encoding stream
    init() {
        remainingOutputRequested = 0
    }

    /// See OutputRequest.requestOutput
    func requestOutput(_ count: UInt) {
        let isSuspended = remainingOutputRequested == 0
        remainingOutputRequested += count
        if isSuspended { update() }
    }

    func update() {
        if remainingOutputRequested > 0 {
            upstream?.requestOutput()
        }
    }

    /// See InputStream.onInput
    func onInput(_ input: ByteBuffer) {
        print("chunking input...")
        // FIXME: Improve performance
        let hexNumber = String(input.count, radix: 16, uppercase: true).data(using: .utf8)!
        let chunk = hexNumber + crlf + Data(input) + crlf
        chunk.withByteBuffer { chunkHandler?($0) }
        remainingOutputRequested -= 1
        update()
    }

    /// See OutputRequest.cancelOutput
    func cancelOutput() {
        // FIXME: cancel the output
    }

    /// See InputStream.onOutput
    func onOutput(_ outputRequest: OutputRequest) {
        self.upstream = outputRequest
    }

    /// See InputStream.onClose
    func onClose() {
        /// FIXME: call close
        closeHandler?()
    }

    /// See OutputStream.onOutput
    func close() {
//        // An empty padding chunk
//        let header = Array(String.init(0, radix: 16, uppercase: true).utf8) + crlf
//        /// FIXME: need to combine this
//        /// FIXME: close can't just output another packet
//        header.withUnsafeBufferPointer(outputStream.onInput)
//        crlf.withUnsafeBufferPointer(outputStream.onInput)
//        onClose()
    }
    
    /// See InputStream.onError
    func onError(_ error: Error) {
        /// FIXME: handle error
    }
    
    /// See OutputStream.output(to:)
    func output<I>(to inputStream: I) where I : Async.InputStream, Output == I.Input {
        chunkHandler = inputStream.onInput
        closeHandler = inputStream.onClose
        inputStream.onOutput(self)
    }
}

private let crlf = Data([.carriageReturn, .newLine])
