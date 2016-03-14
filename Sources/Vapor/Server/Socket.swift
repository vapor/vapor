import Foundation

// MARK: Constants

private let HeaderEndOfLine = "\r\n"

// MARK: Protocols

public protocol Identifiable {
    var id: String { get }
}

public protocol Socket: Identifiable {
    func read(bufferLength: Int) throws -> [Byte]
    func write(buffer: [Byte]) throws
    
    func bind(address: String?, port: String?) throws
    func listen(backlog: Int) throws
    func accept(maximumConsecutiveFailures: Int, connectionHandler: (Socket) -> Void) throws
    
    func close() throws
    
    static func makeSocket() throws -> Socket
}

extension Socket {
    func writeHeader(line line: String) throws {
        try write(line + HeaderEndOfLine)
    }

    func writeHeader(key key: String, val: String) throws {
        try writeHeader(line: "\(key): \(val)")
    }

    func write(string: String) throws {
        try write(string.utf8)
    }

    public func write<ByteSequence: SequenceType where ByteSequence.Generator.Element == Byte>(bytes: ByteSequence) throws {
        try write([UInt8](bytes))
    }
}

// MARK: Read

extension Socket {
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

extension Socket {
    public func readRequest() throws -> Request {
        let header = try Request.Header(self)
        let requestLine = header.requestLine

        let body: [UInt8]
        if let length = header.fields["Content-Length"], let bufferSize = Int(length) {
            body = try read(bufferSize)
        } else {
            body = []
        }


        let method = Request.Method(rawValue: requestLine.method) ?? .Unknown
        let path = requestLine.uri
        // TODO: Figure out whow to get this
        let address = "*"
        return Request(method: method,
                       path: path,
                       address: address,
                       headers: header.fields,
                       body: body)
    }

    public func write(response: Response, keepAlive: Bool = false) throws {
        if let response = response as? AsyncResponse {
            try response.writer(self)
        } else {
            let statusLine = "HTTP/1.1 \(response.status.code) \(response.status)"
            try writeHeader(line: statusLine)

            var headers = response.headers
            if response.data.count >= 0 {
                headers["Content-Length"] = "\(response.data.count)"
            }
            if keepAlive {
                headers["Connection"] = "keep-alive"
            }
            try headers.forEach(writeHeader)

            try write(HeaderEndOfLine)
            try write(response.data)
        }
    }
}
