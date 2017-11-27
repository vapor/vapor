import WebSocket

extension Router {
    public typealias WebSocketClosure = (Request, WebSocket) throws -> Void

    @discardableResult
    public func websocket(_ path: PathComponent...,
        subprotocols: [String]? = nil,
        use closure: @escaping WebSocketClosure
    ) -> Route {
        let responder = RouteResponder { request in
            return try request.upgradeToWebSocket(subprotocols: subprotocols) { websocket in
                try closure(request, websocket)
            }
        }
        let route = Route(method: .get, path: path, responder: responder)
        self.register(route: route)

        return route
    }
}

