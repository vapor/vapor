import Async
import Bits

/// A parser stream.
public final class HTTPParserStream<Parser>: Stream, ConnectionContext where Parser: HTTPParser {
    /// See InputStream.Input
    public typealias Input = ByteBuffer

    /// See OutputStream.Output
    public typealias Output = Parser.Message
    /// The wrapped parser
    private let parser: Parser

    /// Upstream byte buffer stream
    private var upstream: ConnectionContext?

    /// Amount of requested output remaining
    private var remainingMessagesRequested: UInt

    /// Downstream message input stream
    private var downstream: AnyInputStream<Output>?

    /// Create a new parser stream. Call `.stream()` on the parser to create.
    internal init(parser: Parser) {
        self.parser = parser
        remainingMessagesRequested = 0
    }

    /// See ConnectionContext.connection
    public func connection(_ event: ConnectionEvent) {
        switch event {
        case .request(let count):
            /// Called when downstream wants more messages
            let isSuspended = remainingMessagesRequested == 0
            remainingMessagesRequested += count
            if isSuspended { upstream?.request() }
        case .cancel:
            /// Called when downstream wants no more input
            // FIXME: handle
            break
        }
    }

    /// See InputStream.input
    public func input(_ event: InputEvent<ByteBuffer>) {
        // FIXME: HTTP pipelining (more than 1 request/response in a TCP buffer)
        switch event {
        case .connect(let upstream):
            self.upstream = upstream
        case .next(let input):
            do {
                let parsed = try parser.parse(from: input)
                assert(parsed == input.count) // we don't support partial parsing yet

                if let message = parser.message {
                    parser.message = nil // reset
                    downstream?.next(message)
                    remainingMessagesRequested -= 1
                    if remainingMessagesRequested > 0 {
                        upstream?.request()
                    }
                } else {
                    upstream?.request()
                }
            } catch {
                downstream?.error(error)
                parser.message = nil // reset
                upstream?.request()
            }
        case .error(let e): downstream?.error(e)
        case .close:
            downstream?.close()
            // TODO: Closed connections could use closing as an EOF
            // guard let results = getResults(), let headers = results.headers else {
            //     return
            // }
            //
            // if headers[.connection]?.lowercased() == "close", let response = try? makeResponse(from: results) {
            //     self.outputStream.onInput(response)
            // }
        }
    }

    /// See OutputStream.output
    public func output<I>(to inputStream: I) where I: InputStream, Output == I.Input {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }
}

/// MARK: Convenience

extension HTTPParser {
    /// Create a stream for this HTTP parser.
    public func stream() -> HTTPParserStream<Self> {
        return .init(parser: self)
    }
}
