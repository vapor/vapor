private let headerEndOfLine = "\r\n"
private let newLine: Byte = 10
private let carriageReturn: Byte = 13
private let minimumValidAsciiCharacter = carriageReturn + 1

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

struct RequestLine {
    let methodString: String
    let uriString: String
    let version: String

    init(_ string: String) throws {
        let comps = string.components(separatedBy: " ")
        guard comps.count == 3 else {
            throw StreamProxy.Error.InvalidRequestLine
        }

        methodString = comps[0]
        uriString = comps[1]
        version = comps[2]
    }

    var method: Request.Method {
        let method: Request.Method
        switch methodString.lowercased() {
        case "get":
            method = .get
        case "delete":
            method = .delete
        case "head":
            method = .head
        case "post":
            method = .post
        case "put":
            method = .put
        case "connect":
            method = .connect
        case "options":
            method = .options
        case "trace":
            method = .trace
        case "patch":
            method = .patch
        default:
            method = .other(method: methodString)
        }
        return method
    }

    var uri: URI {
        var fields: [String : [String?]] = [:]

        let parts = uriString.split(separator: "?", maxSplits: 1)
        let path = parts.first ?? ""
        let queryString = parts.last ?? ""

        let data = Request.parseFormURLEncoded(queryString.data)

        if case .dictionary(let dict) = data {
            for (key, val) in dict {
                var array: [String?]

                if let existing = fields[key] {
                    array = existing
                } else {
                    array = []
                }

                array.append(val.string)

                fields[key] = array
            }
        }

        return URI(scheme: "http",
                   userInfo: nil,
                   host: nil,
                   port: nil,
                   path: path,
                   query: fields,
                   fragment: nil)
    }
}

public final class StreamProxy {

    enum Error: ErrorProtocol {
        case InvalidHeaderKeyPair
        case InvalidRequestLine
    }

    private var data: IndexingIterator<[Byte]>
    
    private var nextStream: (upTo: Int) throws -> Data

    init(_ stream: HTTPStream) throws {
        self.nextStream =  { length in
            guard stream.open else { return Data() }
            return try stream.receive(upTo: length)
        }
        self.data = try nextStream(upTo: 2048).makeIterator()
    }

    internal func receive(upTo: Int) throws -> [Byte] {
        var received = Array(data)
        let left = upTo - received.count
        if left > 0 {
            received += try nextStream(upTo: left).bytes
        }
        return received
//        var count = 0
//        var bytes = [Byte]()
//        while count < upTo, let next = try nextByte() {
//            bytes.append(next)
//            count += 1
//        }
//        return bytes
    }

    internal func nextByte() throws -> Byte? {
        guard let next = data.next() else {
            data = try nextStream(upTo: 2048).makeIterator()
            return data.next()
        }
        return next
    }

    internal func nextLine() throws -> String {
        var line: String = ""

        func append(byte: Byte) {
            guard byte >= minimumValidAsciiCharacter else {
                return
            }

            line.append(Character(byte))
        }

        while let byte = try nextByte() where byte != newLine {
            append(byte: byte)
        }

        return line
    }

    internal func extractRequestLine() throws -> RequestLine {
        let line = try nextLine()
        return try RequestLine(line)
    }

    internal func extractHeaderFields() throws -> Request.Headers {
        var fields = Request.Headers()

        func headerLine() throws -> String? {
            let line = try nextLine()
            return line.isEmpty ? nil : line
        }

        while let line = try headerLine() {
            let pair = try extractKeyPair(in: line)

            let key = Request.Headers.Key(pair.key)

            var values = fields[key]
            values.append(pair.value)
            fields[key] = values
        }

        return fields
    }

    private func extractKeyPair(in line: String) throws -> (key: String, value: String) {
        let components = line.split(separator: ":", maxSplits: 1)
        guard
            let key = components.first,
            let val = components.last?
                .characters
                .dropFirst()
            else { throw Error.InvalidHeaderKeyPair }

        return (key, String(val))
    }

    func accept() throws -> Request {
        let requestLine = try extractRequestLine()
        let fields = try extractHeaderFields()

        let body: [UInt8]
        if let length = fields.contentLength where length > 0 {
            body = try receive(upTo: length)
        } else {
            body = []
        }

        var uri = requestLine.uri
        if let host = fields["host"].first {
            uri.host = host
        }

        return Request(method: requestLine.method, uri: uri, headers: fields, body: Data(body))
    }
}

import S4

extension S4.Headers {
    var contentLength: Int? {
        guard let lengthString = self["Content-Length"].first else {
            return nil
        }

        guard let length = Int(lengthString) else {
            return nil
        }

        return length
    }
}
