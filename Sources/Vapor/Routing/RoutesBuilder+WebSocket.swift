extension RoutesBuilder {
    #warning("TODO: allow Request here")
    @discardableResult
    public func webSocket(
        _ path: PathComponent...,
        onUpgrade: @escaping (HTTPRequest, Context, WebSocket) -> ()
    ) -> Route {
        return self.on(.GET, path) { (req: HTTPRequest, ctx: Context) -> EventLoopFuture<HTTPResponse> in
            return req.makeWebSocketUpgradeResponse(on: ctx.channel, onUpgrade: { ws in
                onUpgrade(req, ctx, ws)
            })
        }
    }
}
