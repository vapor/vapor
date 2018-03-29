/// Capable of responding to HTTP requests by querying a remote server.
public protocol Client: Responder {
    /// The container to use for creating `Request`s.
    var container: Container { get }
}

extension Client {
    // MARK: Basic

    /// Sends a `GET` request without an HTTP body.
    ///
    ///     try client.get("https://vapor.codes")
    ///
    /// This method calls `send(_:headers:to:)`.
    ///
    /// - parameters:
    ///     - url: The `URL` to connect to and request. This must be a fully-qualified `URL`, not just a path.
    ///     - headers: `HTTPHeaders` optional HTTP headers to attach to the request.
    ///                Empty by default.
    public func get(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.GET, headers: headers, to: url)
    }

    /// Sends a `PUT` request without an HTTP body.
    ///
    ///     try client.put("https://vapor.codes")
    ///
    /// This method calls `send(_:headers:to:)`.
    ///
    /// - parameters:
    ///     - url: The `URL` to connect to and request. This must be a fully-qualified `URL`, not just a path.
    ///     - headers: `HTTPHeaders` optional HTTP headers to attach to the request.
    ///                Empty by default.
    public func put(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.PUT, headers: headers, to: url)
    }

    /// Sends a `POST` request without an HTTP body.
    ///
    ///     try client.post("https://vapor.codes")
    ///
    /// This method calls `send(_:headers:to:)`.
    ///
    /// - parameters:
    ///     - url: The `URL` to connect to and request. This must be a fully-qualified `URL`, not just a path.
    ///     - headers: `HTTPHeaders` optional HTTP headers to attach to the request.
    ///                Empty by default.
    public func post(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.POST, headers: headers, to: url)
    }

    /// Sends a `DELETE` request without an HTTP body.
    ///
    ///     try client.delete("https://vapor.codes")
    ///
    /// This method calls `send(_:headers:to:)`.
    ///
    /// - parameters:
    ///     - url: The `URL` to connect to and request. This must be a fully-qualified `URL`, not just a path.
    ///     - headers: `HTTPHeaders` optional HTTP headers to attach to the request.
    ///                Empty by default.
    public func delete(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.DELETE, headers: headers, to: url)
    }

    /// Sends a `PATCH` request without an HTTP body.
    ///
    ///     try client.patch("https://vapor.codes")
    ///
    /// This method calls `send(_:headers:to:)`.
    ///
    /// - parameters:
    ///     - url: The `URL` to connect to and request. This must be a fully-qualified `URL`, not just a path.
    ///     - headers: `HTTPHeaders` optional HTTP headers to attach to the request.
    ///                Empty by default.
    public func patch(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.PATCH, headers: headers, to: url)
    }

    /// Sends an HTTP request from the `Client` using the `HTTPMethod` and `URL`.
    ///
    ///     try client.send(.get, to: "https://vapor.codes")
    ///
    /// - parameters:
    ///     - method: `HTTPMethod` to use for the request.
    ///     - headers: `HTTPHeaders` optional HTTP headers to attach to the request.
    ///                Empty by default.
    ///     - url: The `URL` to connect to and request. This must be a fully-qualified `URL`, not just a path.
    /// - returns: A future `Response`.
    public func send(_ method: HTTPMethod, headers: HTTPHeaders = .init(), to url: URLRepresentable) -> Future<Response> {
        return Future.flatMap(on: container) {
            let req = Request(using: self.container)
            req.http.method = method
            guard let u = url.converToURL() else {
                throw VaporError(identifier: "clientURL", reason: "Could not convert \(url) to `URL`.", source: .capture())
            }
            req.http.url = u
            req.http.headers = headers
            return try self.respond(to: req)
        }
    }

    // MARK: Content

    /// Sends a `PUT` request with an HTTP body.
    ///
    ///     try client.put("https://vapor.codes", content: "hello")
    ///
    /// This method calls `send(_:headers:to:content:)`.
    ///
    /// - parameters:
    ///     - url: The `URL` to connect to and request. This must be a fully-qualified `URL`, not just a path.
    ///     - headers: `HTTPHeaders` optional HTTP headers to attach to the request.
    ///                Empty by default.
    ///     - content: Generic `Content` to send.
    ///     - mediaType: Optional `MediaType` to specify how the `Content` is encoded.
    ///                  This will be the `Content`'s `defaultMediaType` by default.
    /// - returns: A future `Response`.
    public func put<C>(_ url: URLRepresentable, headers: HTTPHeaders = .init(), content: C, as mediaType: MediaType = C.defaultMediaType) -> Future<Response> where C: Content {
        return send(.PUT, headers: headers, to: url, content: content, as: mediaType)
    }

    /// Sends a `POST` request with an HTTP body.
    ///
    ///     try client.post("https://vapor.codes", content: "hello")
    ///
    /// This method calls `send(_:headers:to:content:)`.
    ///
    /// - parameters:
    ///     - url: The `URL` to connect to and request. This must be a fully-qualified `URL`, not just a path.
    ///     - headers: `HTTPHeaders` optional HTTP headers to attach to the request.
    ///                Empty by default.
    ///     - content: Generic `Content` to send.
    ///     - mediaType: Optional `MediaType` to specify how the `Content` is encoded.
    ///                  This will be the `Content`'s `defaultMediaType` by default.
    /// - returns: A future `Response`.
    public func post<C>(_ url: URLRepresentable, headers: HTTPHeaders = .init(), content: C, as mediaType: MediaType = C.defaultMediaType) -> Future<Response> where C: Content {
        return send(.POST, headers: headers, to: url, content: content, as: mediaType)
    }

    /// Sends a `PATCH` request with an HTTP body.
    ///
    ///     try client.patch("https://vapor.codes", content: "hello")
    ///
    /// This method calls `send(_:headers:to:content:)`.
    ///
    /// - parameters:
    ///     - url: The `URL` to connect to and request. This must be a fully-qualified `URL`, not just a path.
    ///     - headers: `HTTPHeaders` optional HTTP headers to attach to the request.
    ///                Empty by default.
    ///     - content: Generic `Content` to send.
    ///     - mediaType: Optional `MediaType` to specify how the `Content` is encoded.
    ///                  This will be the `Content`'s `defaultMediaType` by default.
    /// - returns: A future `Response`.
    public func patch<C>(_ url: URLRepresentable, headers: HTTPHeaders = .init(), content: C, as mediaType: MediaType = C.defaultMediaType) -> Future<Response> where C: Content {
        return send(.PATCH, headers: headers, to: url, content: content, as: mediaType)
    }

    /// Sends an HTTP request from the `Client` using the `HTTPMethod`, `URL` and `Content`.
    ///
    ///     try client.send(.get, to: "https://vapor.codes", content: "hello!")
    ///
    /// - parameters:
    ///     - method: `HTTPMethod` to use for the request.
    ///     - headers: `HTTPHeaders` optional HTTP headers to attach to the request.
    ///                Empty by default.
    ///     - url: The `URL` to connect to and request. This must be a fully-qualified `URL`, not just a path.
    ///     - content: Generic `Content` to send.
    ///     - mediaType: Optional `MediaType` to specify how the `Content` is encoded.
    ///                  This will be the `Content`'s `defaultMediaType` by default.
    /// - returns: A future `Response`.
    public func send<C>(_ method: HTTPMethod, headers: HTTPHeaders = .init(), to url: URLRepresentable, content: C, as mediaType: MediaType = C.defaultMediaType) -> Future<Response> where C: Content {
        return Future.flatMap(on: container) {
            let req = Request(using: self.container)
            req.http.method = method
            guard let u = url.converToURL() else {
                throw VaporError(identifier: "clientURL", reason: "Could not convert \(url) to `URL`.", source: .capture())
            }
            req.http.url = u
            req.http.headers = headers
            try req.content.encode(content, as: mediaType)
            return try self.respond(to: req)
        }
    }
}
