extension RoutesBuilder {
    #warning("TODO: allow Request here")
    @discardableResult
    public func webSocket(
        _ path: PathComponent...,
        onUpgrade: @escaping (Request, WebSocket) -> ()
    ) -> Route {
        return self.on(.GET, path) { request -> EventLoopFuture<Response> in
            return request.makeWebSocketUpgradeResponse(onUpgrade: { ws in
                onUpgrade(request, ws)
            })
        }
    }
}
