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
        self.buffer = StreamBuffer(stream: stream, buffer: 1024)
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

        let bytes: Data
        if let contentLength = headers["content-length"]?.int {
            bytes = Data(try buffer.chunk(size: contentLength))
        } else {
            bytes = []
        }

        return Request(
            method: requestLine.method,
            uri: requestLine.uri,
            version: requestLine.version,
            headers: Request.Headers(headers),
            body: .buffer(bytes)
        )
    }
}

public final class StreamBuffer {
    private let backingStream: Stream
    private let buffer: Int

    private var iterator: IndexingIterator<[Byte]>

    public init(stream: Stream, buffer: Int = 1024) {
        self.backingStream = stream
        self.buffer = buffer
        self.iterator = Data().makeIterator()
    }

    public func next() throws -> Byte? {
        guard let next = iterator.next() else {
            iterator = try backingStream.receive(upTo: buffer).makeIterator()
            return iterator.next()
        }
        return next
    }

    public func chunk(size: Int) throws -> [Byte] {
        var count = 0
        var bytes = [Byte].init(repeating: 0, count: size)
        while count < size, let byte = try next() {
            bytes[count] = byte
            count += 1
        }
        return bytes
    }
}

import C7

extension StreamBuffer: Stream {}

extension StreamBuffer: C7.Closable {
    public var closed: Bool {
        return backingStream.closed
    }
    public func close() throws {
        try backingStream.close()
    }
}

extension StreamBuffer: Sending {
    public func send(_ data: Data, timingOut deadline: Double) throws {
        try backingStream.send(data, timingOut: deadline)
    }

    public func flush(timingOut deadline: Double) throws {
        try backingStream.flush(timingOut: deadline)
    }
}

extension StreamBuffer: Receiving {
    public func receive(upTo byteCount: Int, timingOut deadline: Double) throws -> Data {
        return try Data(chunk(size: byteCount))
    }
}
