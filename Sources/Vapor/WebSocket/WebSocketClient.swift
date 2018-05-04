extension Client {
    /// Sends an HTTP `GET` `Request` to a server with an optional configuration closure that will run before sending.
    /// This `Request` will ask for upgrade to `WebSocket` protocol.
    ///
    ///     let res = try client.webSocket("http://api.vapor.codes/users")
    ///     print(res) // Future<WebSocket>
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
    ///     - beforeSend: An optional closure that can mutate the `Request` before it is sent.
    /// - returns: A `Future` containing the newly connected `WebSocket` or an `Error`.
    public func webSocket(_ url: URLRepresentable, headers: HTTPHeaders = [:], beforeSend: (Request) throws -> () = { _ in }) -> Future<WebSocket> {
        do {
            let req = Request(http: .init(method: .GET, url: url, headers: headers), using: container)
            try beforeSend(req)
            return try container.make(WebSocketClient.self).webSocketConnect(req)
        } catch {
            return container.eventLoop.newFailedFuture(error: error)
        }
    }
}

/// Capable of connecting to an WebSocket server based on a `Request`.
public protocol WebSocketClient {
    /// Connects to a WebSocket server using the supplied `Request`.
    ///
    /// - parameters:
    ///     - request: HTTP upgrade request to send.
    /// - returns: A `Future` containing the newly connected `WebSocket` or an `Error`.
    func webSocketConnect(_ request: Request) -> Future<WebSocket>
}
