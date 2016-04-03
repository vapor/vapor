private let headerEndOfLine = "\r\n"
private let newLine: Byte = 10
private let carriageReturn: Byte = 13
private let minimumValidAsciiCharacter = carriageReturn + 1

protocol HTTPStream: Stream {
    static func makeStream() -> Self
    func bind(to ip: String?, on port: Int) throws
    func accept(max connectionCount: Int, handler: (HTTPStream -> Void)) throws

    func listen() throws

    func receiveByte() throws -> Byte?
    func receiveLine() throws -> String

    func sendHeaderEndOfLine() throws
    func send(headerLine line: String) throws
    func send(headerKey key: String, headerValue value: String) throws
    func send(string: String) throws

    func receive() throws -> HTTPStreamHeader
    func receive() throws -> Request

    func send(response: Response, keepAlive: Bool) throws
    func send(body: Response.Body) throws
}

extension HTTPStream {
    func receiveByte() throws -> Byte? {
        return try receive(max: 1).first
    }

    func receiveLine() throws -> String {
        var line: String = ""
        func append(byte: Byte) {
            guard byte >= minimumValidAsciiCharacter else { return }
            line.append(Character(byte))
        }

        while
            let next = try receiveByte()
            where next != newLine
            && !closed {
            append(next)
        }

        return line
    }

    func sendHeaderEndOfLine() throws {
        try send(headerEndOfLine)
    }

    func send(headerLine line: String) throws {
        try send(line + headerEndOfLine)
    }

    func send(headerKey key: String, headerValue value: String) throws {
        try send(headerLine: "\(key): \(value)")
    }

    func send(string: String) throws {
        try send(string.data)
    }

    func receive() throws -> HTTPStreamHeader {
        return try HTTPStreamHeader(stream: self)
    }

    func send(response: Response, keepAlive: Bool) throws {
        let version = response.version
        let status = response.status

        let statusLine = "HTTP/\(version.major).\(version.minor) \(status.statusCode) \(status.reasonPhrase)"
        try send(headerLine: statusLine)

        if keepAlive {
            try send(headerKey: "Connection", headerValue: "keep-alive")
        }

        try response.headers.forEach { (key, values) in
            for value in values {
                try send(headerKey: key.string, headerValue: value)
            }
        }
        try sendHeaderEndOfLine()

        try send(response.body)
    }

    func send(body: Response.Body) throws {
        switch body {
        case .buffer(let data):
            try send(data)
        case .receiver(let receiver):
            while !receiver.closed {
                let chunk = try receiver.receive(max: Int.max)
                try send(chunk)
            }
        case .sender(let closure):
            try closure(self)
        }

    }

    func receive() throws -> Request {
        let header: HTTPStreamHeader = try receive()
        let requestLine = header.requestLine

        let data: Data
        if let length = header.contentLength {
            data = try receive(max: length)
        } else {
            data = []
        }
        
        return Request(method: requestLine.method, uri: requestLine.uri, headers: header.fields, body: data)
    }
}
