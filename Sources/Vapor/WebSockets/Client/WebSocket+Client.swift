import CryptoEssentials
import libc

extension WebSocket {
    public static func connect(to uri: String, protocols: [String]? = nil, onConnect: (WebSocket) throws -> Void) throws {
        let uri = try URI(uri)
        try connect(to: uri, protocols: protocols, onConnect: onConnect)
    }

    public static func connect(to uri: URI, protocols: [String]? = nil, onConnect: (WebSocket) throws -> Void) throws {
        let requestKey = WebSocket.makeRequestKey()

        var headers = Headers()
        headers.secWebSocketKey = requestKey
        headers.connection = "Upgrade"
        headers.upgrade = "websocket"
        headers.secWebSocketVersion = "13"
        /*
         If protocols are empty they should not be added,
         it was kicking back errors on nginx proxies in tests
         */
        if let protocols = protocols where !protocols.isEmpty {
            headers.secWebProtocol = protocols
        }

        let client = try HTTPClient<TCPClientStream>(uri)

        let response = try client.get(headers: headers)
        guard response.headers.secWebSocketVersion == "13" else { throw FormatError.invalidOrUnsupportedVersion }
        guard response.headers.connection == "Upgrade" else { throw FormatError.missingConnectionHeader }
        guard response.headers.upgrade == "websocket" else { throw FormatError.missingUpgradeHeader }
        guard case .switchingProtocols = response.status else { throw FormatError.invalidOrUnsupportedStatus }
        guard let accept = response.headers.secWebSocketAccept else { throw FormatError.missingSecAcceptHeader }
        let expected = WebSocket.exchange(requestKey: requestKey)
        guard accept == expected else { throw FormatError.invalidSecAcceptHeader }

        let ws = WebSocket(client.stream)
        try onConnect(ws)
        try ws.listen()
    }
}


extension WebSocket {
    /*
     The request MUST include a header field with the name
     |Sec-WebSocket-Key|.  The value of this header field MUST be a
     nonce consisting of a randomly selected 16-byte value that has
     been base64-encoded (see Section 4 of [RFC4648]).  The nonce
     MUST be selected randomly for each connection.
     */
    static func makeRequestKey() -> String {
        return makeRequestKeyBytes().base64
    }

    private static func makeRequestKeyBytes() -> Bytes {
        return (1...16).map { _ in UInt8.random() }
    }
}

extension UInt8 {
    static func random() -> UInt8 {
        let max = UInt32(UInt8.max)
        #if os(Linux)
            let val = UInt8(libc.random() % Int(max))
        #else
            let val = UInt8(arc4random_uniform(max))
        #endif
        return val
    }
}
