public protocol Client: Program {
    func request(_ method: Method, uri: URI, headers: Headers, query: [String: String], body: HTTPBody) throws -> HTTPResponse
}

public enum ClientsError: ErrorProtocol {
    case unsupportedScheme
}

public enum Clients {
    case plaintext(Client)
    case secure(Client)
    case both(plaintext: Client, secure: Client)
}


extension Clients {
    public func request(_ method: Method, uri: URI, headers: Headers, query: [String: String], body: HTTPBody) throws -> HTTPResponse {
        let isSecure = uri.scheme?.hasSuffix("s") ?? false
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

extension Clients {
    public func get(_ uri: URI, headers: Headers = [:], query: [String: String] = [:], body: HTTPBody = []) throws -> HTTPResponse {
        return try request(.get, uri: uri, headers: headers, query: query, body: body)
    }
    public func post(_ uri: URI, headers: Headers = [:], query: [String: String] = [:], body: HTTPBody = []) throws -> HTTPResponse {
        return try request(.post, uri: uri, headers: headers, query: query, body: body)
    }
    public func put(_ uri: URI, headers: Headers = [:], query: [String: String] = [:], body: HTTPBody = []) throws -> HTTPResponse {
        return try request(.put, uri: uri, headers: headers, query: query, body: body)
    }
    public func patch(_ uri: URI, headers: Headers = [:], query: [String: String] = [:], body: HTTPBody = []) throws -> HTTPResponse {
        return try request(.patch, uri: uri, headers: headers, query: query, body: body)
    }
    public func delete(_ uri: URI, headers: Headers = [:], query: [String: String] = [:], body: HTTPBody = []) throws -> HTTPResponse {
        return try request(.delete, uri: uri, headers: headers, query: query, body: body)
    }
}
