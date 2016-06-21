public protocol Client: Program {
    func request(_ method: Method, uri: URI, headers: Headers, query: [String: String], body: HTTPBody) throws -> HTTPResponse
}

extension Client {
    public func request(_ method: Method, url: String, headers: Headers, query: [String: String], body: HTTPBody) throws -> HTTPResponse {
        let uri = try URIParser.parse(uri: url.bytes)
        return try request(method, uri: uri, headers: headers, query: query, body: body)
    }
    public func get(_ url: String, headers: Headers = [:], query: [String: String] = [:], body: HTTPBody = []) throws -> HTTPResponse {
        return try request(.get, url: url, headers: headers, query: query, body: body)
    }
    public func post(_ url: String, headers: Headers = [:], query: [String: String] = [:], body: HTTPBody = []) throws -> HTTPResponse {
        return try request(.post, url: url, headers: headers, query: query, body: body)
    }
    public func put(_ url: String, headers: Headers = [:], query: [String: String] = [:], body: HTTPBody = []) throws -> HTTPResponse {
        return try request(.put, url: url, headers: headers, query: query, body: body)
    }
    public func patch(_ url: String, headers: Headers = [:], query: [String: String] = [:], body: HTTPBody = []) throws -> HTTPResponse {
        return try request(.patch, url: url, headers: headers, query: query, body: body)
    }
    public func delete(_ url: String, headers: Headers = [:], query: [String: String] = [:], body: HTTPBody = []) throws -> HTTPResponse {
        return try request(.delete, url: url, headers: headers, query: query, body: body)
    }
}

public enum ClientsError: ErrorProtocol {
    case unsupportedScheme
}

public enum Clients {
    case plaintext(Client)
    case secure(Client)
    case both(plaintext: Client, secure: Client)
}

extension Clients: Client {
    public func request(_ method: Method, uri: URI, headers: Headers, query: [String: String], body: HTTPBody) throws -> HTTPResponse {
        let wss = uri.scheme == "wss"
        let https = uri.scheme == "https"
        let isSecure = wss || https

        switch self {
        case .plaintext(let plaintext):
            guard !isSecure else {
                throw ClientsError.unsupportedScheme
            }
            return try plaintext.request(method, uri: uri, headers: headers, query: query, body: body)
        case .secure(let secure):
            guard isSecure else {
                throw ClientsError.unsupportedScheme
            }
            return try secure.request(method, uri: uri, headers: headers, query: query, body: body)
        case .both(let plaintext, let secure):
            if isSecure {
                return try secure.request(method, uri: uri, headers: headers, query: query, body: body)
            } else {
                return try plaintext.request(method, uri: uri, headers: headers, query: query, body: body)
            }
        }
    }
}
