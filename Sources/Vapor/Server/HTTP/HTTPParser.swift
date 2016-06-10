final class HTTPParser: StreamParser {
    enum Error: ErrorProtocol {
        case streamEmpty
    }

    let buffer: StreamBuffer

    /**
        Creates a new HTTP Parser that will
        receive serialized request data from 
        the supplied stream.
    */
    init(stream: Stream) {
        self.buffer = StreamBuffer(stream)
    }

    /**
        Reads and filters non-valid ASCII characters
        from the stream until a new line character is returned.
    */
    func nextLine() throws -> Data {
        var line: Data = []

        while let byte = try buffer.next() where byte != Byte.ASCII.newLine {
            // Skip over any non-valid ASCII characters
            if byte > Byte.ASCII.carriageReturn {
                line.append(byte)
            }
        }

        return line
    }

    /**
        Parses serialized request data from
        the stream following HTTP/1.0 or HTTP/1.1
        protocol.
    */
    func parse() throws -> Request {
        let requestLineString = try nextLine()

        guard !requestLineString.isEmpty else {
            // If the stream is empty, close connection immediately
            throw Error.streamEmpty
        }

        // TODO: Actually parse
        let requestLine = try RequestLine(requestLineString)

        var headers: [Request.Headers.Key: String] = [:]

        while true {
            let headerLine = try nextLine()
            if headerLine.isEmpty {
                // We've reached the end of the headers
                break
            }

            // TODO: Check is line has leading white space
            // This should be converted to values for the
            // previous header

            let comps = headerLine.split(separator: Byte.ASCII.colon)

            guard comps.count == 2 else {
                continue
            }

            let key = Request.Headers.Key(Data(comps[0]).string)

            // TODO: Trim header value from excess whitespace

            let val = Data(comps[1]).string

            headers[key] = val.trim()
        }

        let body: Data

        // TODO: Support transfer-encoding: chunked

        if let contentLength = headers["content-length"]?.int {
            body = try buffer.next(chunk: contentLength)
        } else if
            let transferEncoding = headers["transfer-encoding"]?.string
            where transferEncoding.lowercased() == "chunked"
        {
            var buffer: Data = []

            while true {
                let lengthData = try nextLine()

                // size must be sent
                guard lengthData.count > 0 else {
                    break
                }

                // convert hex length data to int
                guard let length = lengthData.asciiInt else {
                    break
                }

                // end of chunked encoding
                if length == 0 {
                    break
                }

                let content = try self.buffer.next(chunk: length + 2)
                buffer.bytes += content.bytes
            }

            body = buffer
        } else {
            body = []
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
