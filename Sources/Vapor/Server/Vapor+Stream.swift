private let headerEndOfLine = "\r\n"
private let newLine: Byte = 10
private let carriageReturn: Byte = 13
private let minimumValidAsciiCharacter = carriageReturn + 1

extension Stream {
    func receiveByte() throws -> Byte? {
        return try receive(1).first
    }

    func receiveLine() throws -> String {
        var line: String = ""
        func append(byte: Byte) {
            guard byte >= minimumValidAsciiCharacter else { return }
            line.append(Character(byte))
        }

        while let next = try receiveByte() where next != newLine {
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

    func receive() throws -> StreamHeader {
        return try StreamHeader(self)
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
                let chunk = try receiver.receive(Int.max)
                try send(chunk)
            }
        case .sender(let closure):
            try closure(self)
        }

    }

    func receive() throws -> Request {
        let header: StreamHeader = try receive()
        let requestLine = header.requestLine

        let data: Data
        if let length = header.contentLength {
            data = try receive(length)
        } else {
            data = []
        }
        
        return Request(method: requestLine.method, uri: requestLine.uri, headers: header.headers, body: data)
    }
}
