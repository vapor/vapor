extension WebSocketClient {
    public func webSocket(_ url: URI, headers: HTTPHeaders = [:], onUpgrade: @escaping (WebSocket) -> ()) -> EventLoopFuture<Void> {
        return self.webSocket(ClientRequest(method: .GET, url: url, headers: headers, body: nil), onUpgrade: onUpgrade)
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
        return self.connect(host: request.url.host ?? "", port: port, uri: request.url.path, headers: request.headers) { socket in
            onUpgrade(socket)
        }
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

