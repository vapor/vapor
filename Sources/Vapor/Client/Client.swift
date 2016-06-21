public protocol Client: Responder, Program { }

public enum ClientError: ErrorProtocol {

}

extension Client {
    public func request(_ method: Method, path: String, headers: Headers, query: [String: StructuredDataRepresentable], body: HTTPBody) throws -> Response {
        let path = path.finish("/")
        let uri = try URI(path)
        let request = Request(method: method, uri: uri, headers: headers, body: body)

        var structuredData: [String: StructuredData] = [:]
        for (key, val) in query {
            structuredData[key] = val.structuredData
        }

        request.query = .dictionary(structuredData)

        return try respond(to: request)
    }

    public func get(_ path: String, headers: Headers = [:], query: [String: StructuredDataRepresentable] = [:], body: HTTPBody = []) throws -> Response {
        return try request(.get, path: path, headers: headers, query: query, body: body)
    }
    public func post(_ path: String, headers: Headers = [:], query: [String: StructuredDataRepresentable] = [:], body: HTTPBody = []) throws -> Response {
        return try request(.post, path: path, headers: headers, query: query, body: body)
    }
    public func put(_ path: String, headers: Headers = [:], query: [String: StructuredDataRepresentable] = [:], body: HTTPBody = []) throws -> Response {
        return try request(.put, path: path, headers: headers, query: query, body: body)
    }
    public func patch(_ path: String, headers: Headers = [:], query: [String: StructuredDataRepresentable] = [:], body: HTTPBody = []) throws -> Response {
        return try request(.patch, path: path, headers: headers, query: query, body: body)
    }
    public func delete(_ path: String, headers: Headers = [:], query: [String: StructuredDataRepresentable] = [:], body: HTTPBody = []) throws -> Response {
        return try request(.delete, path: path, headers: headers, query: query, body: body)
    }
}
