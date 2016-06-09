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

    func nextLine() throws -> ArraySlice<Byte> {
        return buffer.slice(until: Byte.ASCII.newLine)

        /*
        var line: Data = []

        func append(byte: Byte) {
            guard byte >= HTTPParser.minimumValidAsciiCharacter else {
                return
            }

            line.append(byte)
        }

        while let byte = try buffer.next() where byte != HTTPParser.newLine {
            append(byte: byte)
        }

        return line*/
    }

    func parse() throws -> Request {
        let requestLineString = try nextLine()
        guard !requestLineString.isEmpty else {
            throw Error.streamEmpty
        }

        let requestLine = try RequestLine(requestLineString)

        var headers: [Request.Headers.Key: String] = [:]

        while true {
            let headerLine = try nextLine()
            if headerLine.isEmpty {
                break
            }

            let comps = headerLine.split(separator: Byte.ASCII.colon)

            guard comps.count == 2 else {
                continue
            }

            headers[Request.Headers.Key(String(comps[0]))] = String(comps[1])
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
