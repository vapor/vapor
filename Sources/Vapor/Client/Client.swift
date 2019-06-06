public final class Client {
    private let httpClient: HTTPClient
    private let webSocketClient: WebSocketClient
    private let eventLoop: EventLoop

    public init(
        httpConfiguration: HTTPClient.Configuration = .init(),
        webSocketConfiguration: WebSocketClient.Configuration = .init(),
        on eventLoop: EventLoop
    ) {
        self.httpClient = .init(eventLoopGroupProvider: .shared(eventLoop), configuration: httpConfiguration)
        self.webSocketClient = .init(eventLoopGroupProvider: .shared(eventLoop), configuration: webSocketConfiguration)
        self.eventLoop = eventLoop
    }

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
    public func get(_ url: URI, headers: HTTPHeaders = [:]) -> EventLoopFuture<ClientResponse> {
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
    public func post(_ url: URI, headers: HTTPHeaders = [:]) -> EventLoopFuture<ClientResponse> {
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
    public func patch(_ url: URI, headers: HTTPHeaders = [:]) -> EventLoopFuture<ClientResponse> {
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
    public func put(_ url: URI, headers: HTTPHeaders = [:]) -> EventLoopFuture<ClientResponse> {
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
    public func delete(_ url: URI, headers: HTTPHeaders = [:]) -> EventLoopFuture<ClientResponse> {
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
    public func send(_ method: HTTPMethod, headers: HTTPHeaders = [:], to url: URI) -> EventLoopFuture<ClientResponse> {
        let request = ClientRequest(method: method, url: url, headers: headers, body: nil)
        return self.send(request)
    }

    public func send(_ client: ClientRequest) -> EventLoopFuture<ClientResponse> {
        do {
            let request = try HTTPClient.Request(
                url: URL(string: client.url.string)!,
                version: .init(major: 1, minor: 1),
                method: client.method,
                headers: client.headers, body: client.body.flatMap { .byteBuffer($0) }
            )
            return self.httpClient.execute(request: request).map { response in
                let client = ClientResponse(
                    status: response.status,
                    headers: response.headers,
                    body: response.body
                )
                return client
            }
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
    }

    public func webSocket(_ url: URI, headers: HTTPHeaders = [:], onUpgrade: @escaping (WebSocket) -> ()) -> EventLoopFuture<Void> {
        let port: Int
        if let p = url.port {
            port = p
        } else if let scheme = url.scheme {
            port = scheme == "wss" ? 443 : 80
        } else {
            port = 80
        }
        return self.webSocketClient.connect(host: url.host ?? "", port: port, uri: url.path, headers: headers) { socket in
            onUpgrade(socket)
        }
    }

    public func syncShutdown() throws {
        try self.httpClient.syncShutdown()
        try self.webSocketClient.syncShutdown()
    }
}

extension WebSocketClient.Socket: WebSocket {
    public func onText(_ callback: @escaping (WebSocket, String) -> ()) {
        self.onText { (ws: WebSocketClient.Socket, data: String) in
            callback(ws, data)
        }
    }

    public func onBinary(_ callback: @escaping (WebSocket, ByteBuffer) -> ()) {
        self.onBinary { (ws: WebSocketClient.Socket, data: ByteBuffer) in
            callback(ws, data)
        }
    }

    public func onError(_ callback: @escaping (WebSocket, Error) -> ()) {
        self.onError { (ws: WebSocketClient.Socket, error: Error) in
            callback(ws, error)
        }
    }

    public func send(binary: ByteBuffer, promise: EventLoopPromise<Void>?) {
        var binary = binary
        self.send(binary: binary.readBytes(length: binary.readableBytes)!, promise: promise)
    }
}
