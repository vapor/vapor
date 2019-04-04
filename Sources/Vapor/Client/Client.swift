public protocol Client {
    func send(_ req: HTTPRequest) -> EventLoopFuture<HTTPResponse>
}

extension Client {
    /// Sends an HTTP `GET` `Request` to a server with an optional configuration closure that will run before sending.
    ///
    ///     let res = try client.get("http://api.vapor.codes/users")
    ///     print(res) // Future<Response>
    ///
    /// HTTP `GET` requests are typically used for fetching information and do not have bodies.
    /// However, the `beforeSend` closure is a great place for encoding query string parameters.
    ///
    ///     let res = try client.get("http://api.vapor.codes/users") { get in
    ///         try get.query.encode(["name": "vapor"])
    ///     }
    ///     print(res) // Future<Response>
    ///
    /// - parameters:
    ///     - url: Something `URLRepresentable` that will be converted to a `URL`.
    ///            This `URL` should contain a scheme, hostname, and port.
    ///     - headers: `HTTPHeaders` to add to the request. Empty by default.
    /// - returns: A `Future` containing the requested `Response` or an `Error`.
    public func get(_ url: URLRepresentable, headers: HTTPHeaders = [:]) -> EventLoopFuture<HTTPResponse> {
        return self.send(.GET, headers: headers, to: url)
    }

    /// Sends an HTTP `POST` `Request` to a server with an optional configuration closure that will run before sending.
    ///
    ///     let user: User ...
    ///     let res = try client.post("http://api.vapor.codes/users") { post in
    ///         try post.content.encode(user)
    ///     }
    ///     print(res) // Future<Response>
    ///
    /// - parameters:
    ///     - url: Something `URLRepresentable` that will be converted to a `URL`.
    ///            This `URL` should contain a scheme, hostname, and port.
    ///     - headers: `HTTPHeaders` to add to the request. Empty by default.
    /// - returns: A `Future` containing the requested `Response` or an `Error`.
    public func post(_ url: URLRepresentable, headers: HTTPHeaders = [:]) -> EventLoopFuture<HTTPResponse> {
        return self.send(.POST, headers: headers, to: url)
    }

    /// Sends an HTTP `PATCH` `Request` to a server with an optional configuration closure that will run before sending.
    ///
    ///     let user: User ...
    ///     let res = try client.patch("http://api.vapor.codes/users/42") { patch in
    ///         try patch.content.encode(user)
    ///     }
    ///     print(res) // Future<Response>
    ///
    /// - parameters:
    ///     - url: Something `URLRepresentable` that will be converted to a `URL`.
    ///            This `URL` should contain a scheme, hostname, and port.
    ///     - headers: `HTTPHeaders` to add to the request. Empty by default.
    /// - returns: A `Future` containing the requested `Response` or an `Error`.
    public func patch(_ url: URLRepresentable, headers: HTTPHeaders = [:]) -> EventLoopFuture<HTTPResponse> {
        return self.send(.PATCH, headers: headers, to: url)
    }

    /// Sends an HTTP `PUT` `Request` to a server with an optional configuration closure that will run before sending.
    ///
    ///     let user: User ...
    ///     let res = try client.put("http://api.vapor.codes/users/42") { put in
    ///         try put.content.encode(user)
    ///     }
    ///     print(res) // Future<Response>
    ///
    /// - parameters:
    ///     - url: Something `URLRepresentable` that will be converted to a `URL`.
    ///            This `URL` should contain a scheme, hostname, and port.
    ///     - headers: `HTTPHeaders` to add to the request. Empty by default.
    /// - returns: A `Future` containing the requested `Response` or an `Error`.
    public func put(_ url: URLRepresentable, headers: HTTPHeaders = [:]) -> EventLoopFuture<HTTPResponse> {
        return self.send(.PUT, headers: headers, to: url)
    }

    /// Sends an HTTP `DELETE` `Request` to a server with an optional configuration closure that will run before sending.
    ///
    ///     let res = try client.delete("http://api.vapor.codes/users/42")
    ///     print(res) // Future<Response>
    ///
    /// HTTP `DELETE` requests are typically used for deleting information and do not have bodies.
    /// However, the `beforeSend` closure is a great place for encoding query string parameters.
    ///
    ///     let res = try client.delete("http://api.vapor.codes/users") { get in
    ///         try get.query.encode(["name": "vapor"])
    ///     }
    ///     print(res) // Future<Response>
    ///
    /// - parameters:
    ///     - url: Something `URLRepresentable` that will be converted to a `URL`.
    ///            This `URL` should contain a scheme, hostname, and port.
    ///     - headers: `HTTPHeaders` to add to the request. Empty by default.
    ///     - beforeSend: An optional closure that can mutate the `Request` before it is sent.
    /// - returns: A `Future` containing the requested `Response` or an `Error`.
    public func delete(_ url: URLRepresentable, headers: HTTPHeaders = [:]) -> EventLoopFuture<HTTPResponse> {
        return self.send(.DELETE, headers: headers, to: url)
    }

    /// Sends an HTTP `Request` to a server with an optional configuration closure that will run before sending.
    ///
    ///     let user: User ...
    ///     let res = try client.send(.POST, to: "http://api.vapor.codes/users") { post in
    ///         try post.content.encode(user)
    ///     }
    ///     print(res) // Future<Response>
    ///
    /// - parameters:
    ///     - method: `HTTPMethod` to use for the request.
    ///     - headers: `HTTPHeaders` to add to the request. Empty by default.
    ///     - url: Something `URLRepresentable` that will be converted to a `URL`.
    ///            This `URL` should contain a scheme, hostname, and port.
    ///     - beforeSend: An optional closure that can mutate the `Request` before it is sent.
    /// - returns: A `Future` containing the requested `Response` or an `Error`.
    public func send(_ method: HTTPMethod, headers: HTTPHeaders = [:], to url: URLRepresentable) -> EventLoopFuture<HTTPResponse> {
        let req = HTTPRequest(method: method, url: url, headers: headers)
        return self.send(req)
    }
}
