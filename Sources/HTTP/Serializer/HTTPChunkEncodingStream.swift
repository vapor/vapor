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
    private var remainingOutputRequested: UInt {
        didSet { print("remaining: \(remainingOutputRequested)") }
    }

    /// The downstream input stream.
    private var downstream: AnyInputStream?

    /// If true, the chunk encoder has been closed.
    var isClosed: Bool

    /// Create a new chunk encoding stream
    init() {
        remainingOutputRequested = 0
        isClosed = false
    }

    /// See OutputRequest.requestOutput
    func requestOutput(_ count: UInt) {
        print(count)
        let isSuspended = remainingOutputRequested == 0
        remainingOutputRequested += count
        if isSuspended { update() }
    }

    func update() {
        if remainingOutputRequested > 0 {
            if isClosed {
                print("final chunk")
                // send empty chunk to close stream
                Data().withByteBuffer(onInput)
                downstream?.onClose()
            } else {
                upstream?.requestOutput()
            }
        }
    }

    /// See InputStream.onInput
    func onInput(_ input: ByteBuffer) {
        print("chunking input...")
        // FIXME: Improve performance
        let hexNumber = String(input.count, radix: 16, uppercase: true).data(using: .utf8)!
        let chunk = hexNumber + crlf + Data(input) + crlf
        chunk.withByteBuffer { downstream?.unsafeOnInput($0) }
        remainingOutputRequested -= 1
        update()
    }

    /// See OutputRequest.cancelOutput
    func cancelOutput() {
        // FIXME: cancel the output
    }

    /// See InputStream.onOutput
    func onOutput(_ outputRequest: OutputRequest) {
        isClosed = false
        self.upstream = outputRequest
    }

    /// See InputStream.onClose
    func onClose() {
        print("chunk on close")
        isClosed = true
        update()
    }
    
    /// See InputStream.onError
    func onError(_ error: Error) {
        /// FIXME: handle error
    }
    
    /// See OutputStream.output(to:)
    func output<I>(to inputStream: I) where I : Async.InputStream, Output == I.Input {
        downstream = inputStream
        inputStream.onOutput(self)
    }
}

private let crlf = Data([.carriageReturn, .newLine])
