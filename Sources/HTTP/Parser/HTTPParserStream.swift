import Async
import Bits

/// A parser stream.
public final class HTTPParserStream<Parser>: Stream where Parser: HTTPParser {
    /// See InputStream.Input
    public typealias Input = ByteBuffer

    /// See OutputStream.Output
    public typealias Output = Parser.Message

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output>

    /// The wrapped parser
    private let parser: Parser

    /// Current output request
    private var outputRequest: OutputRequest?

    /// Amount of requested output remaining
    private var remainingMessagesRequested: UInt

    /// Create a new parser stream. Call `.stream()` on the parser to create.
    internal init(parser: Parser) {
        self.parser = parser
        outputStream = .init()
        remainingMessagesRequested = 0
        outputStream.onRequestClosure = onRequest
    }

    /// Called when the byte stream requests more byte buffers
    private func onRequest(count: UInt) {
        let isSuspended = remainingMessagesRequested == 0
        remainingMessagesRequested += count
        if isSuspended {
            outputRequest?.requestOutput()
        }
    }

    /// Handles incoming stream data
    /// See InputStream.onInput
    public func onInput(_ input: ByteBuffer) {
        do {
            let parsed = try parser.parse(max: input.count, from: input)
            assert(parsed == input.count) // we don't partial parsing yet

            if let message = parser.message {
                parser.message = nil // reset
                outputStream.onInput(message)
                remainingMessagesRequested -= 1
                if remainingMessagesRequested > 0 {
                    outputRequest?.requestOutput()
                }
            } else {
                outputRequest?.requestOutput()
            }
        } catch {
            onError(error)
            parser.message = nil // reset
            outputRequest?.requestOutput()
        }
    }

    /// See InputStream.onOutput
    public func onOutput(_ outputRequest: OutputRequest) {
        self.outputRequest = outputRequest
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.output
    public func output<I>(to input: I) where I: InputStream, Output == I.Input {
        outputStream.output(to: input)
    }

    /// See InputStream.onClose
    public func onClose() {
        outputStream.onClose()

        // TODO: Closed connections could use closing as an EOF
//        guard let results = getResults(), let headers = results.headers else {
//            return
//        }
//
//        if headers[.connection]?.lowercased() == "close", let response = try? makeResponse(from: results) {
//            self.outputStream.onInput(response)
//        }
    }
}

/// MARK: Convenience

extension HTTPParser {
    /// Create a stream for this HTTP parser.
    public func stream() -> HTTPParserStream<Self> {
        return .init(parser: self)
    }
}
