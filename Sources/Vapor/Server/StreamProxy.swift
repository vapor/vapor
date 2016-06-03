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
    private var stream: HTTPStream

    init(_ stream: HTTPStream) throws {
        self.stream = stream
        self.data = try stream.receive(upTo: 2048).makeIterator()
    }

    internal func receive(upTo: Int) throws -> [Byte] {
        var count = 0
        var bytes = [Byte]()
        while count < upTo, let next = try nextByte() {
            bytes.append(next)
            count += 1
        }
        return bytes
    }

    internal func nextByte() throws -> Byte? {
        guard let next = data.next() else {
            data = try stream.receive(upTo: 2048).makeIterator()
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
        func headerLine() throws -> String? {
            let line = try nextLine()
            return line.isEmpty ? nil : line
        }

        var fields: [CaseInsensitiveString: String] = [:]
        while let line = try headerLine() {
            let pair = try extractKeyPair(in: line)
            fields[CaseInsensitiveString(pair.key)] = pair.value
        }

        return Request.Headers(fields)
    }

    // Key: Value
    private func extractKeyPair(in line: String) throws -> (key: String, value: String) {
        let components = line.characters.split(separator: ":", maxSplits: 1)
        guard
            let key = components.first,
            let val = components.last?.dropFirst() // drop leading space
            else { throw Error.InvalidHeaderKeyPair }

        return (String(key), String(val))
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
        if let host = fields["host"] {
            uri.host = host
        }

        return Request(method: requestLine.method, uri: uri, headers: fields, body: Data(body))
    }
}

import S4

extension S4.Headers {
    var contentLength: Int? {
        guard let lengthString = self["Content-Length"] else {
            return nil
        }

        guard let length = Int(lengthString) else {
            return nil
        }

        return length
    }
}
