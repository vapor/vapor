import Routing
import WebSocket

extension Router {
    public typealias OnWebsocketUpgradeClosure = (Request, WebSocket) throws -> Void

    /// Registers a websocket route handler at the supplied path.
    /// WebSocketSettings can be used as an [String] to define custom subprotocols.
    ///
    /// example: router.websocket("path", with: ["subprotocol"]) { req, ws in /*...*/ }
    @discardableResult
    public func websocket(_ path: PathComponent...,
        with settings: WebSocketSettings = WebSocketSettings(),
        onUpgrade closure: @escaping OnWebsocketUpgradeClosure) -> Route<Responder> {

        let responder = RouteResponder { (request: Request) -> Future<Response> in
            let http = try WebSocket.upgradeResponse(for: request.http, with: settings) { websocket in
                try closure(request, websocket)
            }

            return Future(Response(http: http, using: request.superContainer))
        }
        let route = Route<Responder>(
            path: [.constants([.bytes(HTTPMethod.get.bytes)])] + path,
            output: responder
        )
        self.register(route: route)

        return route
    }
}
