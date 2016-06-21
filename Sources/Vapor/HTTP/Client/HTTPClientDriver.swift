public protocol Client: Responder {
    init(scheme: String, host: String, port: Int) throws
}

public enum ClientError: ErrorProtocol {
    case unsupportedScheme
}

extension Client {
    public func request(_ method: Method, url: String, headers: Headers, query: [String: String], body: HTTPBody) throws -> HTTPResponse {
        var uri = try URI(url)
        uri.append(query: query)
        let request = Request(method: method, uri: uri)
        return try respond(to: request)
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
