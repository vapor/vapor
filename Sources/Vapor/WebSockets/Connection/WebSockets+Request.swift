public enum WebSocketRequestFormat: ErrorProtocol {
    case missingSecKeyHeader
    case missingUpgradeHeader
    case missingConnectionHeader
    case invalidOrUnsupportedVersion
}

extension Request {
    /**
        Upgrades the request to a WebSocket connection
        WebSocket connection to provide two way information
        transfer between the client and the server.
    */
    public func upgradeToWebSocket(
        supportedProtocols: ([String]) -> [String] = { $0 },
        body: (ws: WebSocket) throws -> Void) throws -> Response {
        guard let requestKey = headers.secWebSocketKey else {
            throw WebSocketRequestFormat.missingSecKeyHeader
        }
        guard headers.upgrade == "websocket" else {
            throw WebSocketRequestFormat.missingUpgradeHeader
        }
        guard headers.connection?.range(of: "Upgrade") != nil else {
            throw WebSocketRequestFormat.missingConnectionHeader
        }

        // TODO: Find other versions and see if we can support -- this is version mentioned in RFC
        guard let version = headers.secWebSocketVersion where version == "13" else {
            throw WebSocketRequestFormat.invalidOrUnsupportedVersion
        }

        var responseHeaders: Headers = [:]
        responseHeaders.connection = "Upgrade"
        responseHeaders.upgrade = "websocket"
        responseHeaders.secWebSocketAccept = WebSocket.exchange(requestKey: requestKey)
        responseHeaders.secWebSocketVersion = version

        if let passedProtocols = headers.secWebProtocol {
            responseHeaders.secWebProtocol = supportedProtocols(passedProtocols)
        }

        var response = Response(status: .switchingProtocols, headers: responseHeaders, cookies: [], data: [])
        response.onUpgrade = { stream in
            let ws = WebSocket(stream)
            try body(ws: ws)
            try ws.listen()
        }
        return response

    }
}
