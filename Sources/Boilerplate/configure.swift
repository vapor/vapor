import Vapor
import Foundation

public func configure(
    _ config: inout Config,
    _ env: inout Environment,
    _ services: inout Services
) throws {
    let router = EngineRouter.default()
    try routes(router) 
    services.register(router, as: Router.self)

    let websockets = EngineWebSocketServer.default()
    websockets.get(.anything) { ws, req in
        ws.onText { ws, text in
            ws.send(text.reversed())
        }
    }
    websockets.get("hi") { ws, req in
        ws.onText { ws, text in
            ws.send("hi")
        }
    }
    services.register(websockets, as: WebSocketServer.self)

    // configure your application here
    let middlewareConfig = MiddlewareConfig()
    // middlewareConfig.use(DateMiddleware.self)
    services.register(middlewareConfig)
}
