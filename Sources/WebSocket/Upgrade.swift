import HTTP
import Crypto

// MARK: Convenience

extension WebSocket {
    /// Returns true if this request should upgrade to websocket protocol
    ///
    /// http://localhost:8000/websocket/upgrade/#determining-an-upgrade
    public static func shouldUpgrade(for req: Request) -> Bool {
        return req.headers[.connection] == "Upgrade" && req.headers[.secWebSocketKey] != nil && req.headers[.secWebSocketVersion] != nil
    }
    
    /// Creates a websocket upgrade response for the upgrade request
    ///
    /// http://localhost:8000/websocket/upgrade/#upgrading-the-connection
    public static func upgradeResponse(for req: Request) throws -> Response {
        guard
            req.method == .get,
            let key = req.headers[.secWebSocketKey],
            let secWebsocketVersion = req.headers[.secWebSocketVersion],
            let version = Int(secWebsocketVersion)
            else {
                throw Error(.invalidRequest)
        }
        
        let headers: Headers
        
        let data = Base64Encoder.encode(data: SHA1.hash(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
        let hash = String(bytes: data, encoding: .utf8) ?? ""
        
        if version > 13 {
            headers = [
                .upgrade: "websocket",
                .connection: "Upgrade",
                .secWebSocketVersion: "13",
                .secWebSocketKey: hash
            ]
        } else {
            headers = [
                .upgrade: "websocket",
                .connection: "Upgrade",
                .secWebSocketAccept: hash
            ]
        }
        
        // Returns an upgrade accept response
        return Response(status: 101, headers: headers)
    }
}

