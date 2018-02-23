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
        to uri: URIRepresentable
    ) -> Future<Response> {
        return Future.flatMap {
            let req = Request(using: self.container)
            req.http.method = method
            req.http.uri = try uri.makeURI()
            req.http.headers = headers
            return try self.respond(to: req)
        }
    }

    /// Sends an HTTP request from the client using the method, url, and content.
    public func send<C>(
        _ method: HTTPMethod,
        headers: HTTPHeaders = [:],
        to uri: URIRepresentable,
        content: C
    ) -> Future<Response> where C: Content {
        return Future.flatMap {
            let req = Request(using: self.container)
            req.http.method = method
            req.http.uri = try uri.makeURI()
            req.http.headers = headers
            try req.content.encode(content)
            return try self.respond(to: req)
        }
    }
}

/// MARK: Basic

extension Client {
    /// Sends a GET request without body
    public func get(_ url: URIRepresentable, headers: HTTPHeaders = [:]) -> Future<Response> {
        return send(.get, headers: headers, to: url)
    }
    
    /// Sends a PUT request without body
    public func put(_ url: URIRepresentable, headers: HTTPHeaders = [:]) -> Future<Response> {
        return send(.put, headers: headers, to: url)
    }
    
    /// Sends a PUT request without body
    public func post(_ url: URIRepresentable, headers: HTTPHeaders = [:]) -> Future<Response> {
        return send(.post, headers: headers, to: url)
    }
    
    /// Sends a POST request without body
    public func delete(_ url: URIRepresentable, headers: HTTPHeaders = [:]) -> Future<Response> {
        return send(.delete, headers: headers, to: url)
    }

    /// Sends a PATCH request without body
    public func patch(_ url: URIRepresentable, headers: HTTPHeaders = [:]) -> Future<Response> {
        return send(.patch, headers: headers, to: url)
    }
}

/// MARK: Content

extension Client {
    /// Sends a PUT request with body
    public func put<C>(_ url: URIRepresentable, headers: HTTPHeaders = [:], content: C) -> Future<Response> where C: Content {
        return send(.put, headers: headers, to: url, content: content)
    }

    /// Sends a POST request with body
    public func post<C>(_ url: URIRepresentable, headers: HTTPHeaders = [:], content: C) -> Future<Response> where C: Content {
        return send(.post, headers: headers, to: url, content: content)
    }

    /// Sends a PATCH request with body
    public func patch<C>(_ url: URIRepresentable, headers: HTTPHeaders = [:], content: C) -> Future<Response> where C: Content {
        return send(.patch, headers: headers, to: url, content: content)
    }
}
