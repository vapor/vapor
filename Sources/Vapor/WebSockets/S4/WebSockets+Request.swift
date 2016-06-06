import S4

extension Request {
    public func upgradeToWebSocket(
        supportedProtocols: ([String]) -> [String] = { $0 },
        body: (ws: WebSock) throws -> Void) throws -> S4.Response {
        guard let requestKey = headers.secWebSocketKey else {
            throw "missing header: Sec-WebSocket-Key"
        }
        guard headers.upgrade == "websocket" else {
            throw "invalid header: Upgrade"
        }
        guard headers.connection == "Upgrade" else {
            throw "invalid header: Connection"
        }

        // TODO: Find other versions and see if we can support
        guard let version = headers.secWebSocketVersion where version == "13" else {
            throw "invalid header: Sec-WebSocket-Version"
        }

        var responseHeaders: Headers = [:]
        responseHeaders.connection = "Upgrade"
        responseHeaders.upgrade = "websocket"
        responseHeaders.secWebSocketAccept = WebSock.exchange(requestKey: requestKey)
        responseHeaders.secWebSocketVersion = version

        if let passedProtocols = headers.secWebProtocol {
            responseHeaders.secWebProtocol = supportedProtocols(passedProtocols)
        }

        var response = S4.Response(status: .switchingProtocols, headers: responseHeaders)
        response.afterResponseSerialization = { stream in
            let ws = WebSock(stream)
            try body(ws: ws)
            try ws.listen()
        }
        return response

    }
}
