import C7

struct HTTPStreamHeader {
    enum Error: ErrorProtocol {
        case InvalidHeaderKeyPair
        case InvalidRequestLine
    }

    let requestLine: RequestLine
    var fields: Request.Headers

    var contentLength: Int? {
        guard let lengthString = fields["Content-Length"].first else {
            return nil
        }

        guard let length = Int(lengthString) else {
            return nil
        }

        return length
    }

    init(stream: HTTPStream) throws {
        fields = Request.Headers()

        let requestLineRaw = try stream.receiveLine()
        requestLine = try RequestLine(requestLineRaw)

        try collectHeaderFields(for: stream)
    }

    private mutating func collectHeaderFields(for socket: HTTPStream) throws {
        while let line = try nextHeaderLine(with: socket) where !socket.closed {
            let pair = try extractKeyPair(in: line)

            let key = Request.Headers.Key(pair.key)

            var values = fields[key]
            values.append(pair.value)
            fields[key] = values
        }
    }

    private func nextHeaderLine(with socket: HTTPStream) throws -> String? {
        let next = try socket.receiveLine()
        if !next.isEmpty {
            return next
        } else {
            return nil
        }
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
}

extension HTTPStreamHeader {
    struct RequestLine {
        let methodString: String
        let uriString: String
        let version: String

        init(_ string: String) throws {
            let comps = string.components(separatedBy: " ")
            guard comps.count == 3 else {
                throw Error.InvalidRequestLine
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

}
