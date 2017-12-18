import Async
import Bits
import Foundation

/// Applies HTTP/1 chunk encoding to a stream of data
final class HTTPChunkEncodingStream: Async.Stream, ConnectionContext {
    /// See InputStream.Input
    typealias Input = ByteBuffer

    /// See OutputStream.Output
    typealias Output = ByteBuffer

    /// Current upstream output request
    /// This should be called when more output is desired.
    private var upstream: ConnectionContext?

    /// Remaining requested output
    private var remainingOutputRequested: UInt

    /// The downstream input stream.
    private var downstream: AnyInputStream<ByteBuffer>?

    /// If true, the chunk encoder has been closed.
    var isClosed: Bool

    /// Create a new chunk encoding stream
    init() {
        remainingOutputRequested = 0
        isClosed = false
    }

    /// See ConnectionContext.connection
    func connection(_ event: ConnectionEvent) {
        switch event {
        case .request(let count):
            let isSuspended = remainingOutputRequested == 0
            remainingOutputRequested += count
            if isSuspended { update() }
        case .cancel:
            // FIXME: cancel the output
            break
        }
    }

    /// See InputStream.input
    func input(_ event: InputEvent<ByteBuffer>) {
        switch event {
        case .connect(let upstream):
            isClosed = false
            self.upstream = upstream
        case .next(let input):
            // FIXME: Improve performance
            print("HEX:" + String(input.count, radix: 16, uppercase: true))
            let hexNumber = String(input.count, radix: 16, uppercase: true).data(using: .utf8)!
            let chunk = hexNumber + crlf + Data(input) + crlf
            chunk.withByteBuffer { downstream?.next($0) }
            remainingOutputRequested -= 1
            update()
        case .error(let error):
            downstream?.error(error)
        case .close:
            isClosed = true
            update()
        }
    }

    /// See OutputStream.output(to:)
    func output<I>(to inputStream: I) where I : Async.InputStream, Output == I.Input {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }

    /// Update the chunk encoders state
    private func update() {
        if remainingOutputRequested > 0 {
            if isClosed {
                // send empty chunk to close stream
                Data().withByteBuffer { input(.next($0)) }
                downstream?.close()
            } else {
                upstream?.request()
            }
        }
    }
}

private let crlf = Data([.carriageReturn, .newLine])
