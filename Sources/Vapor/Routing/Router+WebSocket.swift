import Routing
import WebSocket

extension Router {
    /// Registers a websocket route handler at the supplied path.
    /// WebSocketSettings can be used as an [String] to define custom subprotocols.
    ///
    /// example: router.websocket("path", with: ["subprotocol"]) { req, ws in /*...*/ }
    @discardableResult
    public func websocket(_ path: PathComponent...,
        with settings: WebSocketSettings = WebSocketSettings(),
        onUpgrade closure: @escaping WebSocket.OnUpgradeClosure) -> Route<Responder> {

        let responder = RouteResponder { (request: Request) -> Response in
            let http = try WebSocket.upgradeResponse(for: request.http, with: settings, onUpgrade: closure)
            return Response(http: http, using: request.superContainer)
        }
        let route = Route<Responder>(
            path: [.constants([.bytes(HTTPMethod.get.bytes)])] + path,
            output: responder
        )
        self.register(route: route)

        return route
    }
}


