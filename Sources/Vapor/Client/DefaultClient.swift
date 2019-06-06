public final class DefaultClient: Client {
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

    public func webSocket(_ request: ClientRequest, onUpgrade: @escaping (WebSocket) -> ()) -> EventLoopFuture<Void> {
        let port: Int
        if let p = request.url.port {
            port = p
        } else if let scheme = request.url.scheme {
            port = scheme == "wss" ? 443 : 80
        } else {
            port = 80
        }
        return self.webSocketClient.connect(host: request.url.host ?? "", port: port, uri: request.url.path, headers: request.headers) { socket in
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
