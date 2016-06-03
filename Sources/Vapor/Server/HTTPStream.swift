internal let headerEndOfLine = "\r\n"
internal let newLine: Byte = 10
internal let carriageReturn: Byte = 13
internal let minimumValidAsciiCharacter = carriageReturn + 1

protocol HTTPStream: Stream, AsyncStream {
    func sendHeaderEndOfLine() throws
    func send(headerLine line: String) throws
    func send(headerKey key: String, headerValue value: String) throws
    func send(_ string: String) throws

    func send(_ response: Response, keepAlive: Bool) throws
    func send(_ body: Response.Body) throws
}

extension HTTPStream {
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

        try headers.forEach { (key, value) in
            try send(headerKey: key.string, headerValue: value)
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
}


protocol HTTPListenerStream: HTTPStream {
    init(address: String?, port: Int) throws
    func bind() throws
    func listen() throws
    func accept(max connectionCount: Int, handler: ((HTTPStream) -> Void)) throws
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

extension HTTPStream {
    var open: Bool {
        return !closed
    }
}
