import HTTP
import Crypto

// MARK: Convenience

extension WebSocket {
    /// Returns true if this request should upgrade to websocket protocol
    public static func shouldUpgrade(for req: Request) -> Bool {
        return req.headers[.connection] == "Upgrade" && req.headers[.upgrade] == "websocket"
    }
    
    /// Creates a websocket upgrade response for the upgrade request
    public static func upgradeResponse(for req: Request) throws -> Response {
        guard
            req.method == .get,
            let key = req.headers["Sec-WebSocket-Key"],
            let secWebsocketVersion = req.headers["Sec-WebSocket-Version"],
            let version = Int(secWebsocketVersion)
            else {
                throw Error(.invalidRequest)
        }
        
        let headers: Headers
        
        let data = try Base64Encoder.encode(data: SHA1.hash(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
        let hash = String(bytes: data, encoding: .utf8) ?? ""
        
        if version > 13 {
            headers = [
                "Upgrade": "websocket",
                "Connection": "Upgrade",
                "Sec-WebSocket-Version": "13",
                "Sec-WebSocket-Key": hash
            ]
        } else {
            headers = [
                "Upgrade": "websocket",
                "Connection": "Upgrade",
                "Sec-WebSocket-Accept": hash
            ]
        }
        
        // Returns an upgrade accept response
        return Response(status: 101, headers: headers)
    }
}

