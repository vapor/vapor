import Async
import WebSocket
import HTTP
import Routing

extension Router {
    public typealias WebSocketClosure = (Request, WebSocket) throws -> Void

    @discardableResult
    public func socket(_ path: PathComponent...,
        subprotocols: [String]? = nil,
        use closure: @escaping WebSocketClosure) -> Route {
        return socket(path, supportedProtocols: { subprotocols ?? $0 }, use: closure)
    }

    @discardableResult
    public func socket(_ path: PathComponent...,
        supportedProtocols: @escaping ([String]) -> [String] = { $0 },
        use closure: @escaping WebSocketClosure) -> Route {
        return socket(path, supportedProtocols: supportedProtocols, use: closure)
    }

    private func socket(_ path: [PathComponent],
                        supportedProtocols: @escaping ([String]) -> [String],
                        use closure: @escaping WebSocketClosure) -> Route {

        let responder = RouteResponder { request in
            return try request.upgradeToWebSocket(subprotocols: supportedProtocols) { websocket in
                try closure(request, websocket)
            }
        }
        let route = Route(method: .get, path: path, responder: responder)
        self.register(route: route)

        return route
    }
}

