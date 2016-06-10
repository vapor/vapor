final class HTTPParser: StreamParser {
    enum Error: ErrorProtocol {
        case streamEmpty
    }

    static let headerEndOfLine = "\r\n"
    static let newLine: Byte = 10
    static let carriageReturn: Byte = 13
    static let minimumValidAsciiCharacter: Byte = 13 + 1

    let buffer: StreamBuffer

    init(stream: Stream) {
        self.buffer = StreamBuffer(stream, buffer: 1024)
    }

    func nextLine() throws -> String {
        var line: String = ""

        func append(byte: Byte) {
            guard byte >= HTTPParser.minimumValidAsciiCharacter else {
                return
            }

            line.append(Character(byte))
        }

        while let byte = try buffer.next() where byte != HTTPParser.newLine {
            append(byte: byte)
        }

        return line
    }

    func parse() throws -> Request {
        let requestLineString = try nextLine()
        guard !requestLineString.isEmpty else {
            throw Error.streamEmpty
        }

        // TODO: Actually parse
        let requestLine = try RequestLine(requestLineString)

        var headers: [Request.Headers.Key: String] = [:]

        while true {
            let headerLine = try nextLine()
            if headerLine.isEmpty {
                break
            }

            let comps = headerLine.components(separatedBy: ": ")

            guard comps.count == 2 else {
                continue
            }

            headers[Request.Headers.Key(comps[0])] = comps[1]
        }

        var body: Data = []

        // TODO: Support transfer-encoding: chunked

        if let contentLength = headers["content-length"]?.int {
            for _ in 0..<contentLength {
                if let byte = try buffer.next() {
                    body.append(byte)
                }
            }
        }

        return Request(
            method: requestLine.method,
            uri: requestLine.uri,
            version: requestLine.version,
            headers: Request.Headers(headers),
            body: .buffer(body)
        )
    }
}

extension String: ErrorProtocol {}

final class RequestParser {
    enum Error: ErrorProtocol {
        case streamEmpty
    }

    private var localBuffer: [Byte] = []
    private let buffer: StreamBuffer

    /**
     Creates a new HTTP Parser that will
     receive serialized request data from
     the supplied stream.
     */
    init(stream: Stream) {
        self.buffer = StreamBuffer(stream)
    }

    func parse() throws {

    }

    /*
     https://tools.ietf.org/html/rfc2616#section-5.1

     The Request-Line begins with a method token, followed by the
     Request-URI and the protocol version, and ending with CRLF. The
     elements are separated by SP characters. No CR or LF is allowed
     except in the final CRLF sequence.

     Request-Line   = Method SP Request-URI SP HTTP-Version CRLF
     */
    func parseRequestLine() throws -> (method: [Byte], uri: [Byte], httpVersion: [Byte]) {
        try skipWhiteSpace()
        let method = try collect(until: .space)
        try discardNext(1) // discard space
        let uri = try collect(until: .space)
        try discardNext(1) // discard space
        let httpVersion = try collect(until: .carriageReturn)
        // should pick up carriage return in buffer, and expect subsequent line feed
        // CRLF
        let trailing = try collect(next: 2)
        guard trailing == [.carriageReturn, .lineFeed] else { throw "expected request line terminator" }
        return (method, uri, httpVersion)
    }

    private func skipWhiteSpace() throws {
        while let next = try next() {
            if next.isWhitespace { continue }

            /*
             Found first non whitespace, return to buffer
             */
            returnToBuffer(next)
            break
        }
    }

    /**
     // TODO: Merge Overlapping Behavior w/ Static Buffer
     */
    // MARK: - ##########

    // MARK: Next

    func next() throws -> Byte? {
        /*
         local buffer is used to maintain last bytes while still interacting w/ byte buffer
         */
        guard localBuffer.isEmpty else {
            return localBuffer.removeFirst()
        }
        return try buffer.next()
    }

    // MARK:

    func returnToBuffer(_ byte: Byte) {
        returnToBuffer([byte])
    }

    func returnToBuffer(_ bytes: [Byte]) {
        localBuffer.append(contentsOf: bytes)
    }

    // MARK: Discard Extranneous Tokens

    func discardNext(_ count: Int) throws {
        _ = try collect(next: count)
    }

    // MARK: Check Tokens

    func checkLeadingBuffer(matches: Byte...) throws -> Bool {
        return try checkLeadingBuffer(matches: matches)
    }

    func checkLeadingBuffer(matches: [Byte]) throws -> Bool {
        let leading = try collect(next: matches.count)
        returnToBuffer(leading)
        return leading == matches
    }

    // MARK: Collection

    func collect(next count: Int) throws -> [Byte] {
        guard count > 0 else { return [] }

        var body: [Byte] = []
        try (1...count).forEach { _ in
            guard let next = try next() else { return }
            body.append(next)
        }
        return body
    }

    /*
     When in Query segment, `+` should be interpreted as ` ` (space), not sure useful outside of that point
     */
    func collect(until delimitters: Byte..., convertIfNecessary: (Byte) -> Byte = { $0 }) throws -> [Byte] {
        var collected: [Byte] = []
        while let next = try next() {
            if delimitters.contains(next) {
                // If the delimitter is also a token that identifies
                // a particular section of the URI
                // then we may want to return that byte to the buffer
                returnToBuffer(next)
                break
            }

            let converted = convertIfNecessary(next)
            collected.append(converted)
        }
        return collected
    }

    //    func collectRemaining() throws -> [Byte] {
    //        var complete: [Byte] = []
    //        while let next = try next() {
    //            complete.append(next)
    //        }
    //        return complete
    //    }
}
