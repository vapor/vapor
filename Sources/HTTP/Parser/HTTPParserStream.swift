import Async
import Bits

/// A parser stream.
public final class HTTPParserStream<Parser>: Stream, OutputRequest where Parser: HTTPParser {
    /// See InputStream.Input
    public typealias Input = ByteBuffer

    /// See OutputStream.Output
    public typealias Output = Parser.Message
    /// The wrapped parser
    private let parser: Parser

    /// Upstream byte buffer stream
    private var upstream: OutputRequest?

    /// Amount of requested output remaining
    private var remainingMessagesRequested: UInt

    /// Downstream message input stream
    private var downstream: AnyInputStream!

    /// Create a new parser stream. Call `.stream()` on the parser to create.
    internal init(parser: Parser) {
        self.parser = parser
        remainingMessagesRequested = 0
    }

    /// Called when downstream wants more messages
    public func requestOutput(_ count: UInt) {
        let isSuspended = remainingMessagesRequested == 0
        remainingMessagesRequested += count
        if isSuspended { upstream?.requestOutput() }
    }

    /// Called when downstream wants no more input
    public func cancelOutput() {
        // FIXME: handle
    }

    /// Handles incoming stream data
    /// See InputStream.onInput
    public func onInput(_ input: ByteBuffer) {
        do {
            let parsed = try parser.parse(max: input.count, from: input)
            assert(parsed == input.count) // we don't partial parsing yet

            if let message = parser.message {
                parser.message = nil // reset
                downstream.unsafeOnInput(message)
                remainingMessagesRequested -= 1
                if remainingMessagesRequested > 0 {
                    upstream?.requestOutput()
                }
            } else {
                upstream?.requestOutput()
            }
        } catch {
            onError(error)
            parser.message = nil // reset
            upstream?.requestOutput()
        }
    }

    /// See InputStream.onOutput
    public func onOutput(_ outputRequest: OutputRequest) {
        self.upstream = outputRequest
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        downstream.onError(error)
    }

    /// See OutputStream.output
    public func output<I>(to input: I) where I: InputStream, Output == I.Input {
        downstream = input
        input.onOutput(self)
    }

    /// See InputStream.onClose
    public func onClose() {
        downstream.onClose()

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
