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

        let requestLine = try RequestLine(requestLineString)

        var headers: [CaseInsensitiveString: String] = [:]

        while true {
            let headerLine = try nextLine()
            if headerLine.isEmpty {
                break
            }

            let comps = headerLine.components(separatedBy: ": ")

            guard comps.count == 2 else {
                continue
            }

            headers[CaseInsensitiveString(comps[0])] = comps[1]
        }

        var body: Data = []
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
