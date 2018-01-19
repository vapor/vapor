import HTTP

/// Responds to HTTP requests.
public protocol Client: Responder {
    /// The container to use for creating requests.
    var container: Container { get }
}

// MARK: Convenience

extension Client {
    /// Sends an HTTP request from the client using the method and url.
    public func send(
        _ method: HTTPMethod,
        headers: HTTPHeaders = [:],
        to url: URI
    ) -> Future<Response> {
        return Future.flatMap {
            let req = Request(using: self.container)
            req.http.method = method
            req.http.uri = url
            req.headers = headers
            return try self.respond(to: req)
        }
    }

    /// Sends an HTTP request from the client using the method, url, and content.
    public func send<C: Content>(
        _ method: HTTPMethod,
        headers: HTTPHeaders = [:],
        to url: URI,
        content: C
    ) -> Future<Response> {
        return Future.flatMap {
            let req = Request(using: self.container)
            try req.content.encode(content)
            req.http.method = method
            req.http.uri = url
            return try self.respond(to: req)
        }
    }
}

extension Client {
    /// Sends a GET request without body
    public func get(_ url: URI, headers: HTTPHeaders = [:]) -> Future<Response> {
        return send(.get, headers: headers, to: url)
    }
    
    /// Sends a GET request with body
    public func get<C: Content>(_ url: URI, headers: HTTPHeaders = [:], content: C) -> Future<Response> {
        return send(.get, headers: headers, to: url, content: content)
    }
    
    /// Sends a PUT request without body
    public func put(_ url: URI, headers: HTTPHeaders = [:]) -> Future<Response> {
        return send(.put, headers: headers, to: url)
    }
    
    /// Sends a GET request with body
    public func put<C: Content>(_ url: URI, headers: HTTPHeaders = [:], content: C) -> Future<Response> {
        return send(.put, headers: headers, to: url, content: content)
    }
    
    /// Sends a PUT request without body
    public func post(_ url: URI, headers: HTTPHeaders = [:]) -> Future<Response> {
        return send(.post, headers: headers, to: url)
    }
    
    /// Sends a POST request with body
    public func post<C: Content>(_ url: URI, headers: HTTPHeaders = [:], content: C) -> Future<Response> {
        return send(.post, headers: headers, to: url, content: content)
    }
    
    /// Sends a POST request without body
    public func delete(_ url: URI, headers: HTTPHeaders = [:]) -> Future<Response> {
        return send(.delete, headers: headers, to: url)
    }
    
    /// Sends a POST request with body
    public func delete<C: Content>(_ url: URI, headers: HTTPHeaders = [:], content: C) -> Future<Response> {
        return send(.delete, headers: headers, to: url, content: content)
    }
    
    /// Sends a PATCH request without body
    public func patch(_ url: URI, headers: HTTPHeaders = [:]) -> Future<Response> {
        return send(.patch, headers: headers, to: url)
    }
    
    /// Sends a PATCH request with body
    public func patch<C: Content>(_ url: URI, headers: HTTPHeaders = [:], content: C) -> Future<Response> {
        return send(.patch, headers: headers, to: url, content: content)
    }
}
