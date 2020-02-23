extension RoutesBuilder {
    @discardableResult
    public func webSocket(
        _ path: PathComponent...,
        maxFrameSize: Int? = nil,
        onUpgrade: @escaping (Request, WebSocket) -> ()
    ) -> Route {
        return self.on(.GET, path) { request -> Response in
            let res = Response(status: .switchingProtocols)
            res.upgrader = .webSocket(maxFrameSize: maxFrameSize, onUpgrade: { ws in
                onUpgrade(request, ws)
            })
            return res
        }
    }
}
