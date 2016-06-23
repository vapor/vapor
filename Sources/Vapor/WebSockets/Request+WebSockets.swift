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
            throw WebSocket.FormatError.missingSecKeyHeader
        }
        guard headers.upgrade == "websocket" else {
            throw WebSocket.FormatError.missingUpgradeHeader
        }
        guard headers.connection?.range(of: "Upgrade") != nil else {
            throw WebSocket.FormatError.missingConnectionHeader
        }

        // TODO: Find other versions and see if we can support -- this is version mentioned in RFC
        guard let version = headers.secWebSocketVersion where version == "13" else {
            throw WebSocket.FormatError.invalidOrUnsupportedVersion
        }

        var responseHeaders: Headers = [:]
        responseHeaders.connection = "Upgrade"
        responseHeaders.upgrade = "websocket"
        responseHeaders.secWebSocketAccept = WebSocket.exchange(requestKey: requestKey)
        responseHeaders.secWebSocketVersion = version

        if let passedProtocols = headers.secWebProtocol {
            responseHeaders.secWebProtocol = supportedProtocols(passedProtocols)
        }

        let response = HTTPResponse(status: .switchingProtocols, headers: responseHeaders)
        response.onComplete = { stream in
            let ws = WebSocket(stream, mode: .server)
            try body(ws: ws)
            try ws.listen()
        }
        return response
        
    }
}
