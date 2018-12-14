import Vapor

public func configure(_ s: inout Services) throws {
    s.register(Router.self) { c in
        let r = try c.make(EngineRouter.self)
        try routes(r, c)
        return r
    }
//    let serverConfig = NIOServerConfig.default(hostname: "127.0.0.1")
//    services.register(serverConfig)
//
//    let router = EngineRouter.default()
//    try routes(router) 
//    services.register(router, as: Router.self)
//
//    // Create a new NIO websocket server
//    let wss = NIOWebSocketServer.default()
//
//    // Add WebSocket upgrade support to GET /echo
//    wss.get("echo") { ws, req in
//        // Add a new on text callback
//        ws.onText { ws, text in
//            // Simply echo any received text
//            ws.send(text)
//        }
//    }
//
//    // Add WebSocket upgrade support to GET /chat/:name
//    wss.get("chat", String.parameter) { ws, req in
//        let name = try req.parameters.next(String.self)
//        ws.send("Welcome, \(name)!")
//        // ...
//    }
//
//    // Register our server
//    services.register(wss, as: WebSocketServer.self)
//
//    // no middleware
//    // services.register(MiddlewareConfig())
//
//    // configure your application here
}
