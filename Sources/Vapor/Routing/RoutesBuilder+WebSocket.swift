public struct WebSocketMaxFrameSize: ExpressibleByIntegerLiteral {
    let value: Int

    public init(integerLiteral value: Int) {
        self.value = value
    }

    public static var `default`: Self {
        self.init(integerLiteral: 1 << 14)
    }
}

extension RoutesBuilder {
    @discardableResult
    public func webSocket(
        _ path: PathComponent...,
        maxFrameSize: WebSocketMaxFrameSize = .`default`,
        shouldUpgrade: ((Request) -> EventLoopFuture<HTTPHeaders?>)? = nil,
        onUpgrade: @escaping (Request, WebSocket) -> ()
    ) -> Route {
        return self.webSocket(path, maxFrameSize: maxFrameSize, shouldUpgrade: shouldUpgrade, onUpgrade: onUpgrade)
    }

    @discardableResult
    public func webSocket(
        _ path: [PathComponent],
        maxFrameSize: WebSocketMaxFrameSize = .`default`,
        shouldUpgrade: ((Request) -> EventLoopFuture<HTTPHeaders?>)? = nil,
        onUpgrade: @escaping (Request, WebSocket) -> ()
    ) -> Route {
        return self.on(.GET, path) { request -> Response in
            let res = Response(status: .switchingProtocols)
            let shouldUpgradeWrapped = shouldUpgrade.map { shouldUpgrade in { shouldUpgrade(request) } }
            res.upgrader = .webSocket(maxFrameSize: maxFrameSize, shouldUpgrade: shouldUpgradeWrapped, onUpgrade: { ws in
                onUpgrade(request, ws)
            })
            return res
        }
    }
}
