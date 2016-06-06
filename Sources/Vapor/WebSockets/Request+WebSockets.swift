import SHA1
import CryptoEssentials

extension WebSock {
    // UUID defined here: https://tools.ietf.org/html/rfc6455#section-1.3
    private static let hashKey = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    /*
     For this header field, the server has to take the value (as present
     in the header field, e.g., the base64-encoded [RFC4648] version minus
     any leading and trailing whitespace) and concatenate this with the
     Globally Unique Identifier (GUID, [RFC4122]) "258EAFA5-E914-47DA-
     95CA-C5AB0DC85B11" in string form, which is unlikely to be used by
     network endpoints that do not understand the WebSocket Protocol.  A
     SHA-1 hash (160 bits) [FIPS.180-3], base64-encoded (see Section 4 of
     [RFC4648]), of this concatenation is then returned in the server's
     handshake.

     Concretely, if as in the example above, the |Sec-WebSocket-Key|
     header field had the value "dGhlIHNhbXBsZSBub25jZQ==", the server
     would concatenate the string "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
     to form the string "dGhlIHNhbXBsZSBub25jZQ==258EAFA5-E914-47DA-95CA-
     C5AB0DC85B11".  The server would then take the SHA-1 hash of this,
     giving the value 0xb3 0x7a 0x4f 0x2c 0xc0 0x62 0x4f 0x16 0x90 0xf6
     0x46 0x06 0xcf 0x38 0x59 0x45 0xb2 0xbe 0xc4 0xea.  This value is
     then base64-encoded (see Section 4 of [RFC4648]), to give the value
     "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=".  This value would then be echoed in
     the |Sec-WebSocket-Accept| header field.
     */
    static func exchange(requestKey: String) -> String {
        let combination = requestKey.trim() + hashKey
        let shaBytes = SHA1.calculate(combination)
        let hashed = shaBytes.base64
        return hashed
    }
}

/*

 extension String {
 // TODO: Fewer foundation deps
 func makeWebSocketSecKeyExchange() -> String {
 // UUID defined here: https://tools.ietf.org/html/rfc6455#section-1.3
 let HashKey = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
 let combined = self.trim() + HashKey
 let shaBytes = SHA1.calculate(combined)
 let endMarker = NSData(bytes: shaBytes, length: shaBytes.count)
 let hashed = endMarker.base64EncodedString(.encoding64CharacterLineLength)
 return hashed
 }
 func toBase64() -> String {
 let d = data(using: NSUTF8StringEncoding)
 return d!.base64EncodedString(.encoding64CharacterLineLength)
 //        return d!.base64EncodedData(NSDataBase64EncodingOptions.encoding64CharacterLineLength)
 }

 static func fromBase64(_ string: String) -> String {
 let d = NSData.init(base64Encoded: string, options: .ignoreUnknownCharacters)
 return String.init(data: d!, encoding: NSUTF8StringEncoding)!
 }
 }

 app.get("socket") { request in

 print("Get socket: \(request)")
 func socketHandler(_ socket: Stream) throws {
 let ws = WebSock.init(socket)
 ws.textEvent.subscribe { data, text in
 print("Got \(data.text)")
 // TODO: rm !
 try data.ws.send("thank you for text \(data.text)\n\n\t:)\n")

 if data.text == "close" {
 try data.ws.send("\n\tCLOSING\n")
 try data.ws.initiateClose()
 }
 }
 try ws.listen()
 }

 let secReturn = request.headers["Sec-WebSocket-Key"]!.makeWebSocketSecKeyExchange()
 //    let combined = inputKey + HashKey
 //    let hashed = combined.toBase64()
 //    HTTP/1.1 101 Switching Protocols
 //    Upgrade: websocket
 //    Connection: Upgrade
 //    Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
 //    Sec-WebSocket-Protocol: chat
 var headers: Headers = [:]
 headers["Connection"] = "Upgrade"
 headers["Upgrade"] = "websocket"
 // NOTE: Note that request has -Key, return has -Accept
 headers["Sec-WebSocket-Accept"] = secReturn
 //    headers["Sec-WebSocket-Version"] = "13"
 // TODO: Read up and clarify this
 //    headers["Sec-WebSocket-Protocol"] = request.headers["Sec-WebSocket-Protocol"]
 var response = Response.init(status: .switchingProtocols, headers: headers)//, headers: Headers, cookies: Cookies, body: Stream)
 response.webSocketConnection = socketHandler
 print("\n\nReturning: \(response)\n\n")
 return response
 }
 */
import S4

extension Request {
    public func upgradeToWebSocket(_ body: (ws: WebSock) throws -> Void) throws -> S4.Response {
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

        // TODO: Protocols are application specific, should be exposed via API
        let protocols = headers.secWebProtocol ?? []

        var responseHeaders: Headers = [:]
        responseHeaders.connection = "Upgrade"
        responseHeaders.upgrade = "websocket"
        responseHeaders.secWebSocketAccept = WebSock.exchange(requestKey: requestKey)
        responseHeaders.secWebSocketVersion = version

        var response = S4.Response.init(status: .switchingProtocols, headers: responseHeaders)
        response.webSocketConnection = body
        return response
//
//        // TODO: Read up and clarify this
//        //    headers["Sec-WebSocket-Protocol"] = request.headers["Sec-WebSocket-Protocol"]
//        var response = Response.init(status: .switchingProtocols, headers: headers)//, headers: Headers, cookies: Cookies, body: Stream)
//        response.webSocketConnection = socketHandler
//        print("\n\nReturning: \(response)\n\n")
//        return response

    }
}

// https://tools.ietf.org/html/rfc6455#section-1.2
extension Request.Headers {
    public var isWebSocketRequest: Bool {
        guard upgrade == "websocket" else { return false }
        guard connection == "Upgrade" else { return false }
        guard secWebSocketKey != nil else { return false }
        // TODO: Other versions support? This is the one in RFC
        guard secWebSocketVersion == "13" else { return false }
        // secWebSocketProtocol is _not_ required?
        return true
    }

    public var upgrade: String? {
        get {
            return self["Upgrade"]
        }
        set {
            self["Upgrade"] = newValue
        }
    }

    public var connection: String? {
        get {
            return self["Connection"]
        }
        set {
            self["Connection"] = newValue
        }
    }

    public var secWebSocketKey: String? {
        get {
            return self["Sec-WebSocket-Key"]
        }
        set {
            self["Sec-WebSocket-Key"] = newValue
        }
    }

    public var secWebSocketVersion: String? {
        get {
            return self["Sec-WebSocket-Version"]
        }
        set {
            self["Sec-WebSocket-Version"] = newValue
        }
    }

    public var secWebSocketAccept: String? {
        get {
            return self["Sec-WebSocket-Accept"]
        }
        set {
            self["Sec-WebSocket-Accept"] = newValue
        }
    }

    public var secWebProtocol: [String]? {
        get {
            return self["Sec-Websockt-Protocol"]?.components(separatedBy: ", ")
        }
        set {
            let joined = newValue?.joined(separator: ", ")
            self["Sec-Websockt-Protocol"] = joined
        }
    }
}
