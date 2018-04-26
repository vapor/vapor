extension Request {
    public func client() throws -> Client {
        return try make()
    }
}

/// Connects to remote HTTP servers and sends HTTP requests receiving HTTP responses.
///
///     let res = try req.client().get("http://vapor.codes")
///     print(res) // Future<Response>
///
/// See `FoundationClient` and `EngineClient`.
public protocol Client {
    /// The `Container` to use for creating `Request`s.
    var container: Container { get }

    func send(_ req: Request) -> Future<Response>
}

extension Client {
    // MARK: Basic

    /// Sends a GET request without body
    public func get(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.GET, headers: headers, to: url)
    }

    /// Sends a PUT request without body
    public func put(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.PUT, headers: headers, to: url)
    }

    /// Sends a POST request without body
    public func post(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.POST, headers: headers, to: url)
    }

    /// Sends a DELETE request without body
    public func delete(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.DELETE, headers: headers, to: url)
    }

    /// Sends a PATCH request without body
    public func patch(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.PATCH, headers: headers, to: url)
    }

    // MARK: Content

    /// Sends a GET request without body
    public func get<Q>(_ url: URLRepresentable, headers: HTTPHeaders = .init(), query: Q) -> Future<Response> where Q: Encodable {
        return send(.GET, headers: headers, to: url, query: query)
    }

    /// Sends a PUT request with body
    public func put<C>(_ url: URLRepresentable, headers: HTTPHeaders = .init(), content: C) -> Future<Response> where C: Content {
        return send(.PUT, headers: headers, to: url, content: content)
    }

    /// Sends a POST request with body
    public func post<C>(_ url: URLRepresentable, headers: HTTPHeaders = .init(), content: C) -> Future<Response> where C: Content {
        return send(.POST, headers: headers, to: url, content: content)
    }

    /// Sends a PATCH request with body
    public func patch<C>(_ url: URLRepresentable, headers: HTTPHeaders = .init(), content: C) -> Future<Response> where C: Content {
        return send(.PATCH, headers: headers, to: url, content: content)
    }

    // MARK: Custom

    /// Sends an HTTP request from the client using the method and url.
    public func send(_ method: HTTPMethod, headers: HTTPHeaders = .init(), to url: URLRepresentable) -> Future<Response> {
        return _send(method, headers: headers, to: url) { _ in }
    }

    public func send<C>(
        _ method: HTTPMethod,
        headers: HTTPHeaders = .init(),
        to url: URLRepresentable,
        content: C
    ) -> Future<Response> where C: Content {
        return send(method, headers: headers, to: url, as: C.defaultContentType, content: content)
    }

    public func send<C, Q>(
        _ method: HTTPMethod,
        headers: HTTPHeaders = .init(),
        to url: URLRepresentable,
        content: C,
        query: Q
    ) -> Future<Response> where C: Content, Q: Encodable {
        return send(method, headers: headers, to: url, content: content, as: C.defaultContentType, query: query)
    }

    public func send<Q>(
        _ method: HTTPMethod,
        headers: HTTPHeaders = .init(),
        to url: URLRepresentable,
        query: Q
    ) -> Future<Response> where Q: Encodable {
        return _send(method, headers: headers, to: url) { req in
            try req.query.encode(query)
        }
    }

    public func send<C>(
        _ method: HTTPMethod,
        headers: HTTPHeaders = .init(),
        to url: URLRepresentable,
        as mediaType: MediaType,
        content: C
    ) -> Future<Response> where C: Encodable {
        return _send(method, headers: headers, to: url) { req in
            try req.content.encode(content, as: mediaType)
        }
    }

    public func send<C, Q>(
        _ method: HTTPMethod,
        headers: HTTPHeaders = .init(),
        to url: URLRepresentable,
        content: C,
        as mediaType: MediaType,
        query: Q
    ) -> Future<Response> where C: Encodable, Q: Encodable {
        return _send(method, headers: headers, to: url) { req in
            try req.content.encode(content, as: mediaType)
            try req.query.encode(query)
        }
    }

    public func send(http: HTTPRequest) -> Future<Response> {
        let req = Request(http: http, using: container)
        return send(req)
    }

    // MARK: Private

    /// Private send that has a closure for accessing request containers.
    private func _send(
        _ method: HTTPMethod,
        headers: HTTPHeaders,
        to url: URLRepresentable,
        closure: (Request) throws -> ()
    ) -> Future<Response> {
        do {
            let req = Request(using: container)
            req.http.method = method
            req.http.url = url.convertToURL() ?? .root
            req.http.headers = headers
            try closure(req)
            return send(req)
        } catch {
            return container.eventLoop.newFailedFuture(error: error)
        }
    }
}
