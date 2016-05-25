private let headerEndOfLine = "\r\n"
private let newLine: Byte = 10
private let carriageReturn: Byte = 13
private let minimumValidAsciiCharacter = carriageReturn + 1

protocol HTTPStream: Stream, AsyncStream {
    func receiveByte() throws -> Byte?
    func receiveLine() throws -> String

    func sendHeaderEndOfLine() throws
    func send(headerLine line: String) throws
    func send(headerKey key: String, headerValue value: String) throws
    func send(_ string: String) throws

    func receive() throws -> HTTPStreamHeader
    func receive() throws -> Request

    func send(_ response: Response, keepAlive: Bool) throws
    func send(_ body: Response.Body) throws
}

protocol HTTPListenerStream: HTTPStream {
    init(address: String?, port: Int) throws
    func bind() throws
    func listen() throws
    func accept(max connectionCount: Int, handler: ((HTTPStream) -> Void)) throws
}

extension HTTPStream {
    func receiveByte() throws -> Byte? {
        return try receive(upTo: 1).first
    }

    func receiveLine() throws -> String {
        var line: String = ""

        func append(byte: Byte) {
            guard byte >= minimumValidAsciiCharacter else {
                return
            }

            line.append(Character(byte))
        }

        while !closed, let byte = try receiveByte() where byte != newLine {
            append(byte: byte)
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

    func send(_ string: String) throws {
        try send(string.data)
    }

    func receive() throws -> HTTPStreamHeader {
        return try HTTPStreamHeader(stream: self)
    }

    func send(_ response: Response, keepAlive: Bool) throws {
        let version = response.version
        let status = response.status

        let statusLine = "HTTP/\(version.major).\(version.minor) \(status.statusCode) \(status.reasonPhrase)"
        try send(headerLine: statusLine)

        if keepAlive {
            try send(headerKey: "Connection", headerValue: "keep-alive")
        }

        let headers = response.headers.sorted { a, b in
            return a.key.string < b.key.string
        }

        try headers.forEach { (key, values) in
            for value in values {
                try send(headerKey: key.string, headerValue: value)
            }
        }
        try sendHeaderEndOfLine()

        try send(response.body)
    }

    func send(_ body: Response.Body) throws {
        switch body {
        case .buffer(let data):
            try send(data)
        case .receiver(let receiver):
            while !receiver.closed {
                let chunk = try receiver.receive(upTo: Int.max)
                try send(chunk)
            }
        case .sender(let closure):
            try closure(self)
        case .asyncSender(let sender):
            sender(self) { closure in
                let _ = try? closure()
            }
        case .asyncReceiver(let receiver):
            while !receiver.closed {
                receiver.receive(upTo: Int.max) { closure in
                    if let data = try? closure() {
                        let _ = try? self.send(data)
                    }
                }
            }
        }
    }

    func receive() throws -> Request {
        let header: HTTPStreamHeader = try receive()
        let requestLine = header.requestLine


        let data: Data
        if let length = header.contentLength where length > 0 {
            data = try receive(upTo: length)
        } else {
            data = []
        }

        var uri = requestLine.uri
        if let host = header.fields["host"].first {
            uri.host = host
        }
        
        return Request(method: requestLine.method, uri: uri, headers: header.fields, body: data)
    }
}

/**
    One of the error types thrown by your conformers of `HTTPStream` should
    conform to this protocol. This error type specially handles when a receive
    fails because the other side closed the connection. This is an expected
    issue when the client decides they don't want to communicate with the
    server anymore.
 */
public protocol HTTPStreamError: ErrorProtocol {
    /// `true` if the error indicates the socket was closed, otherwise `false`
    var isClosedByPeer: Bool { get }
}
