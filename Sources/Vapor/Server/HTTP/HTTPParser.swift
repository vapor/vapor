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
