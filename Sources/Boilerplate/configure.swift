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

    let websockets = EngineWebSocketServer.default { ws, req in
        ws.onText { text in
            ws.send(text.reversed())
        }
    }
    services.register(websockets, as: WebSocketServer.self)

    // configure your application here
    let middlewareConfig = MiddlewareConfig()
    // middlewareConfig.use(DateMiddleware.self)
    services.register(middlewareConfig)
}
