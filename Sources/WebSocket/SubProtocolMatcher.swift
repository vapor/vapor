import HTTP

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
            // TODO: Add warning log: "Unsupported subprotocol. Request: \(request). Router: \(router)"
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

