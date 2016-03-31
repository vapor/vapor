import S4

// MARK: Constants
private let HeaderEndOfLine = "\r\n"

// MARK: Protocols
public protocol SocketIO {
    func read(bufferLength: Int) throws -> [Byte]
    func write(buffer: [Byte]) throws
}

public protocol Socket: SocketIO {
    func bind(toAddress address: String?, onPort port: String?) throws
    func listen(pendingConnectionBacklog backlog: Int) throws
    func accept(maximumConsecutiveFailures: Int, connectionHandler: (Self) -> Void) throws

    func close() throws

    static func makeSocket() throws -> Self
}

extension SocketIO {
    func writeHeader(line line: String) throws {
        try write(line + HeaderEndOfLine)
    }

    func writeHeader(key key: String, val: String) throws {
        try writeHeader(line: "\(key): \(val)")
    }

    func write(string: String) throws {
        try write(string.utf8)
    }

    public func write<ByteSequence: Sequence where ByteSequence.Iterator.Element == Byte>(bytes: ByteSequence) throws {
        try write([UInt8](bytes))
    }
}

// MARK: Read
extension SocketIO {
    public func nextByte() throws -> Byte? {
        return try read(1).first
    }

    internal func readLine() throws -> String {
        var line: String = ""
        func append(byte: Byte) {
            // Possible minimum bad name here because we expect `>=`. Or make minimum '14'
            guard byte >= MinimumValidAsciiCharacter else { return }
            line.append(Character(byte))
        }

        while let next = try nextByte() where next != NewLine {
            append(next)
        }

        return line
    }
}

// MARK: Request / Response
extension SocketIO {
    public func readRequest() throws -> S4.Request {
        let header = try Header(self)
        let requestLine = header.requestLine

        //Body
        let bytes: [UInt8]
        if let length = header.fields["Content-Length"], let bufferSize = Int(length) {
            bytes = try read(bufferSize)
        } else {
            bytes = []
        }
        let data = S4.Data(bytes)

        
        //Method
        let method: S4.Method
        switch requestLine.method.lowercased() {
        case "get":
            method = .get
        default:
            method = .other(method: requestLine.method)
        }
        
        //URI
        let path = requestLine.uri
        let uri = S4.URI(scheme: "http", userInfo: nil, host: nil, port: nil, path: path, query: [], fragment: nil)
        
        //Headers
        var headers = S4.Headers([:])
        for (key, value) in header.fields {
            headers[CaseInsensitiveString(key)] = HeaderValues(value)
        }
        
        return S4.Request(method: method, uri: uri, headers: headers, body: data)
    }

    public func write(response: S4.Response, keepAlive: Bool) throws {
        let version = response.version
        let status = response.status

        let statusLine = "HTTP/\(version.major).\(version.minor) \(status.statusCode) \(status.reasonPhrase)"
        try writeHeader(line: statusLine)
        
        if keepAlive {
            try writeHeader(key: "Connection", val: "keep-alive")
        }
        
        try response.headers.forEach { (key, values) in
            for value in values {
                try writeHeader(key: key.string, val: value)
            }
        }
        try write(HeaderEndOfLine)
        
        switch response.body {
        case .buffer(let data):
            try write(data)
        case .stream(let stream):
            while !stream.closed {
                let chunk = try stream.receive()
                try write(chunk.bytes)
            }
        }
    }
}
