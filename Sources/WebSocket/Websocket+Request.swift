import HTTP

extension Request {
    public func upgradeToWebSocket(subprotocols: [String]? = nil,
                                   body: @escaping (WebSocket) throws -> Void) throws -> Response {
        guard WebSocket.shouldUpgrade(for: self) else {
            throw WebSocketError(.notUpgraded)
        }

        let requestWebSocketProtocols = self.requestWebSocketProtocols

        let matcher = SubProtocolMatcher(request: requestWebSocketProtocols,
                                         router: subprotocols ?? requestWebSocketProtocols)
        let matchingSubProtocol = try matcher.matching()

        let response = try WebSocket.upgradeResponse(for: self)

        if let subProtocol = matchingSubProtocol {
            response.headers[.secWebSocketProtocol] = subProtocol
        }

        response.onUpgrade = { client in
            let ws = WebSocket(socket: client)
            try? body(ws)
        }

        return response
    }

    private var requestWebSocketProtocols: [String] {
        return headers[.secWebSocketProtocol]?.components(separatedBy: ", ") ?? []
    }
}

struct SubProtocolMatcher {
    let request: [String]
    let router: [String]

    init(request: [String], router: [String]) {
        self.request = request.filter { !$0.isEmpty }
        self.router = router.filter { !$0.isEmpty }
    }

    func matching() throws -> String? {
        if request.isEmpty && router.isEmpty {
            return nil
        }

        if request.isEmpty || router.isEmpty {
            print("Unsupported subprotocol. Request: \(request). Router: \(router)")
            throw WebSocketError(.invalidSubprotocol)
        }

        for subprotocol in router {
            if request.contains(subprotocol) {
                return subprotocol
            }
        }

        throw WebSocketError(.invalidSubprotocol)
    }
}

