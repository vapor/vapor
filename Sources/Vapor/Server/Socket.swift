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
    public func readRequest() throws -> Request {
        let header = try Header(self)
        let requestLine = header.requestLine

        //Body
        let bytes: [UInt8]
        if let length = header.fields["Content-Length"], let bufferSize = Int(length) {
            bytes = try read(bufferSize)
        } else {
            bytes = []
        }
        let data = Data(bytes)
        
        //Method
        let method: Request.Method
        switch requestLine.method.lowercased() {
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
            method = .other(method: requestLine.method)
        }
        
        //URI
        let pathParts = requestLine.uri.split("?", maxSplits: 1)
        let path = pathParts.first ?? ""
        let queryString = pathParts.last ?? ""
        let queryParts = queryString.split("&")

        var queries: [URI.Query] = []
        for part in queryParts {
            let parts = part.split("=")

            let value: String?

            if let v = parts.last {
                value = (try? String(percentEncoded: v)) ?? v
            } else {
                value = nil
            }

            let query = URI.Query(key: parts.first ?? "", value: value)
            queries.append(query)
        }


        let uri = URI(scheme: "http", userInfo: nil, host: nil, port: nil, path: path, query: queries, fragment: nil)
        
        //Headers
        var headers = Headers([:])
        for (key, value) in header.fields {
            headers[Headers.Key(key)] = Headers.Values(value)
        }
        
        return Request(method: method, uri: uri, headers: headers, body: data)
    }

    public func write(response: Response, keepAlive: Bool) throws {
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
