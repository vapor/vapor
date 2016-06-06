import S4

// https://tools.ietf.org/html/rfc6455#section-1.2
extension Request.Headers {
    public var isWebSocketRequest: Bool {
        guard upgrade == "websocket" else { return false }
        guard connection == "Upgrade" else { return false }
        guard secWebSocketKey != nil else { return false }
        // TODO: Other versions support? This is the one in RFC
        guard secWebSocketVersion == "13" else { return false }
        // secWebSocketProtocol is _not_ required
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
            return self["Sec-WebSocket-Protocol"]?.components(separatedBy: ", ")
        }
        set {
            let joined = newValue?.joined(separator: ", ")
            self["Sec-WebSocket-Protocol"] = joined
        }
    }
}
