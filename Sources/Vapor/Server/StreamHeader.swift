

struct StreamHeader {
    enum Error: ErrorProtocol {
        case InvalidHeaderKeyPair
        case InvalidComponents
    }

    let requestLine: RequestLine
    private(set) var fields: [String : String] = [:]

    var fieldsArray: [(String, String)] {
        var array: [(String, String)] = []
        for (key, val) in fields {
            array.append((key, val))
        }
        return array
    }

    var contentLength: Int? {
        guard let lengthString = fields["Content-Length"] else {
            return nil
        }

        guard let length = Int(lengthString) else {
            return nil
        }

        return length
    }

    var headers: Request.Headers {
        var headers = Request.Headers([:])
        for (key, value) in fields {
            headers[Request.Headers.Key(key)] = Request.Headers.Values(value)
        }
        return headers
    }

    init(_ socket: Stream) throws {
        let requestLineRaw = try socket.receiveLine()
        requestLine = try RequestLine(requestLineRaw)
        try collectHeaderFields(socket)
    }

    private mutating func collectHeaderFields(socket: Stream) throws {
        while let line = try nextHeaderLine(socket) {
            let (key, val) = try extractKeyPair(line)
            fields[key] = val
        }
    }

    private func nextHeaderLine(socket: Stream) throws -> String? {
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

extension StreamHeader: CustomStringConvertible {
    var description: String {
        var fieldsDescription = ""
        fields.forEach { key, val in
            Log.info("K**\(key)**")
            fieldsDescription += "    \(key): \(val)\n"
        }
        return "\n\(requestLine)\n\n\(fieldsDescription)"
    }
}

extension StreamHeader {
    internal struct RequestLine {
        let methodString: String
        let uriString: String
        let version: String

        init(_ string: String) throws {
            let comps = string.split(" ")
            guard comps.count == 3 else {
                throw Error.InvalidComponents
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

extension StreamHeader.RequestLine: CustomStringConvertible {
    var description: String {
        return "\nMethod: \(method)\nUri: \(uri)\nVersion: \(version)"
    }
}
