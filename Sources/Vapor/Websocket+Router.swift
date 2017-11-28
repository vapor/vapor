import WebSocket

extension Router {
    /// Registers a websocket route handler at the supplied path.
    /// WebSocketSettings can be used as an [String] to define custom subprotocols.
    ///
    /// example: router.websocket("path", with: ["subprotocol"]) { req, ws in /*...*/ }
    @discardableResult
    public func websocket(_ path: PathComponent...,
        with settings: WebSocketSettings = WebSocketSettings(),
        onUpgrade closure: @escaping WebSocket.OnUpgradeClosure) -> Route {

        let responder = RouteResponder { request in
            return try WebSocket.upgradeResponse(for: request, with: settings, onUpgrade: closure)
        }
        let route = Route(method: .get, path: path, responder: responder)
        self.register(route: route)

        return route
    }
}

