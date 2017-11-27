import HTTP

extension Request {
    public func upgradeToWebSocket(subprotocols: ([String]) -> [String] = { $0 },
                                   body: @escaping (WebSocket) throws -> Void) throws -> Response {
        guard WebSocket.shouldUpgrade(for: self) else {
            throw WebSocketError(.notUpgraded)
        }

        let matchingSubProtocol = try SubProtocolMatcher(request: requestWebSocketProtocol,
                                                         router: subprotocols(requestWebSocketProtocol)).matching()

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

    private var requestWebSocketProtocol: [String] {
        return headers[.secWebSocketProtocol]?.components(separatedBy: ", ") ?? []
    }
}

struct SubProtocolMatcher {
    let request: [String]
    let router: [String]




    //    Request : ["aprotocol", "minichat-v2"]
    //    Router  : ["aprotocol", "minichat-v2"]
    //    Response: "aprotocol"
    //
    //
    //    Request : ["aprotocol", "minichat-v2"]
    //    Router  : ["minichat-v2"]
    //    Response: "minichat-v2"
    //
    //
    //    Request : ["minichat-v2"]
    //    Router  : ["aprotocol", "minichat-v2"]
    //    Response: "minichat-v2"
    //
    //
    //    Request : ["aprotocol", "minichat-v2"]
    //    Router  : []
    //    Response: throw unsupported subprotocol
    //
    //
    //    Request : []
    //    Router  : ["aprotocol", "minichat-v2"]
    //    Response: throw unsupported subprotocol

    func matching() throws -> String? {
        if request.isEmpty && router.isEmpty {
            return nil
        }

        if request.isEmpty || router.isEmpty {
            print("Unsupported subprotocol. Request: \(request). Router: \(router)")
            throw WebSocketError(.invalidRequest)
        }

        for subprotocol in router {
            if request.contains(subprotocol) {
                return subprotocol
            }
        }

        throw WebSocketError(.invalidRequest)
    }
}
