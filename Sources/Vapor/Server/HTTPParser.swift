final class HTTPParser {

    static let headerEndOfLine = "\r\n"
    static let newLine: Byte = 10
    static let carriageReturn: Byte = 13
    static let minimumValidAsciiCharacter: Byte = 13 + 1

    var stream: Stream
    var iterator: IndexingIterator<[Byte]>

    init(stream: Stream) {
        self.stream = stream
        self.iterator = Data().makeIterator()
    }

    func next() throws -> Byte? {
        guard let next = iterator.next() else {
            iterator = try stream.receive(upTo: 2048).makeIterator()
            return iterator.next()
        }
        return next
    }

    func nextLine() throws -> String {
        var line: String = ""

        func append(byte: Byte) {
            guard byte >= HTTPParser.minimumValidAsciiCharacter else {
                return
            }

            line.append(Character(byte))
        }

        while let byte = try next() where byte != HTTPParser.newLine {
            append(byte: byte)
        }
        
        return line
    }

    func chunk(size: Int) throws -> [Byte] {
        var bytes = [Byte].init(repeating: 0, count: size)
        bytes += Array(iterator)
        iterator = Data().makeIterator()

        while bytes.count < size {
            let next = try stream.receive(upTo: 2048)
            bytes.append(contentsOf: next)
        }

        return bytes
    }

    func parse() throws -> Request {
        var requestLineString = ""
        while requestLineString.isEmpty {
            requestLineString = try nextLine()
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

        let buffer: Data
        if let contentLength = headers["content-length"]?.int {
            buffer = Data(try chunk(size: contentLength))
        } else {
            buffer = []
        }

        return Request(
            method: requestLine.method,
            uri: requestLine.uri,
            version: requestLine.version,
            headers: Request.Headers(headers),
            body: .buffer(buffer)
        )
    }
}


extension Data {
    var nextLine: String? {
        var bytes: [Byte] = []

        var it = makeIterator()
        while let byte = it.next() where byte != HTTPParser.newLine {
            bytes.append(byte)
        }

        return String(bytes)
    }
}
