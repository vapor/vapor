import HTTP
import Crypto

// MARK: Convenience

extension WebSocket {
    public typealias OnUpgradeClosure = (WebSocket) throws -> Void

    /// Returns true if this request should upgrade to websocket protocol
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/websocket/upgrade/#determining-an-upgrade)	§
    public static func shouldUpgrade(for req: HTTPRequest) -> Bool {
        return req.headers[.connection] == "Upgrade" && req.headers[.secWebSocketKey] != nil && req.headers[.secWebSocketVersion] != nil
    }
    
    /// Creates a websocket upgrade response for the upgrade request
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/websocket/upgrade/#upgrading-the-connection)
    public static func upgradeResponse(
        for request: HTTPRequest,
        with settings: WebSocketSettings
    ) throws -> HTTPResponse {
        guard shouldUpgrade(for: request) else {
            throw WebSocketError(.invalidRequest)
        }

        try settings.apply(on: request)

        let headers = try buildWebSocketHeaders(for: request)
        var response = HTTPResponse(status: 101, headers: headers)

        try settings.apply(on: &response, request: request)

        return response
    }

    /// Creates a websocket upgrade response for the upgrade request
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/websocket/upgrade/#upgrading-the-connection)
    public static func upgradeResponse(
        for request: HTTPRequest,
        with settings: WebSocketSettings,
        onUpgrade: @escaping OnUpgradeClosure
    ) throws -> HTTPResponse {
        var response = try upgradeResponse(for: request, with: settings)

        response.onUpgrade = HTTPOnUpgrade { tcpClient in
            let websocket = WebSocket(socket: tcpClient)
            // Does it make sense to be defined here? If someone calls the above method, the websocket won't be set according to the given settings.
            try? settings.apply(on: websocket, request: request, response: response)

            try? onUpgrade(websocket)
        }

        return response
    }

    private static func buildWebSocketHeaders(for req: HTTPRequest) throws -> HTTPHeaders {
        guard
            req.method == .get,
            let key = req.headers[.secWebSocketKey],
            let secWebsocketVersion = req.headers[.secWebSocketVersion],
            let version = Int(secWebsocketVersion)
        else {
            throw WebSocketError(.invalidRequest)
        }

        let data = Base64Encoder().encode(data: SHA1.hash(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
        let hash = String(bytes: data, encoding: .utf8) ?? ""

        var headers: HTTPHeaders = [
            .upgrade: "websocket",
            .connection: "Upgrade",
            .secWebSocketAccept: hash
        ]

        guard version > 13 else {
            return headers
        }

        headers[.secWebSocketVersion] = "13"
        return headers
    }
}

