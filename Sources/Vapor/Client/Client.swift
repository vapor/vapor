public protocol Client {
    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse>
}

public struct ClientRequest {
    public var method: HTTPMethod
    public var url: URL
    public var headers: HTTPHeaders
    public var body: ByteBuffer?
    
    public init(method: HTTPMethod = .GET, url: URL = .root, headers: HTTPHeaders = [:], body: ByteBuffer? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct ClientResponse: CustomStringConvertible {
    public var status: HTTPStatus
    public var headers: HTTPHeaders
    public var body: ByteBuffer?
    
    public var description: String {
        var desc = ["HTTP/1.1 \(status.code) \(status.reasonPhrase)"]
        desc += self.headers.map { "\($0.name): \($0.value)" }
        if var body = self.body {
            let string = body.readString(length: body.readableBytes) ?? ""
            desc += ["", string]
        }
        return desc.joined(separator: "\n")
    }
    
    public init(status: HTTPStatus = .ok, headers: HTTPHeaders = [:], body: ByteBuffer? = nil) {
        self.status = status
        self.headers = headers
        self.body = body
    }
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
    public func get(_ url: URLRepresentable, headers: HTTPHeaders = [:]) -> EventLoopFuture<ClientResponse> {
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
    public func post(_ url: URLRepresentable, headers: HTTPHeaders = [:]) -> EventLoopFuture<ClientResponse> {
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
    public func patch(_ url: URLRepresentable, headers: HTTPHeaders = [:]) -> EventLoopFuture<ClientResponse> {
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
    public func put(_ url: URLRepresentable, headers: HTTPHeaders = [:]) -> EventLoopFuture<ClientResponse> {
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
    public func delete(_ url: URLRepresentable, headers: HTTPHeaders = [:]) -> EventLoopFuture<ClientResponse> {
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
    public func send(_ method: HTTPMethod, headers: HTTPHeaders = [:], to url: URLRepresentable) -> EventLoopFuture<ClientResponse> {
        let request = ClientRequest(method: method, url: url.convertToURL()!, headers: headers, body: nil)
        return self.send(request)
    }
}
