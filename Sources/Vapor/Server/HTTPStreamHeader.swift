

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

        try collectHeaderFields(stream)
    }

    private mutating func collectHeaderFields(socket: HTTPStream) throws {
        while let line = try nextHeaderLine(socket) where !socket.closed {
            let (key, value) = try extractKeyPair(line)
            fields[Request.Headers.Key(key)] = Request.Headers.Values(value)
        }
    }

    private func nextHeaderLine(socket: HTTPStream) throws -> String? {
        let next = try socket.receiveLine()
        if !next.isEmpty {
            return next
        } else {
            return nil
        }
    }

    private func extractKeyPair(line: String) throws -> (key: String, value: String) {
        let components = line.split(":", maxSplits: 1)
        guard let key = components.first, let val = components.last?.characters.dropFirst() else { throw Error.InvalidHeaderKeyPair }

        return (key, String(val))
    }
}

extension HTTPStreamHeader {
    struct RequestLine {
        let methodString: String
        let uriString: String
        let version: String

        init(_ string: String) throws {
            let comps = string.split(" ")
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
            let pathParts = uriString.split("?", maxSplits: 1)
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

            
            return URI(scheme: "http", userInfo: nil, host: nil, port: nil, path: path, query: queries, fragment: nil)
        }
    }

}
