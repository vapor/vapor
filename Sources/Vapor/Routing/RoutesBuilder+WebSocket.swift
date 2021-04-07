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
        onUpgrade: @escaping (Request, WebSocket) -> ()
    ) -> Route {
        return self.webSocket(path, maxFrameSize: maxFrameSize, onUpgrade: onUpgrade)
    }

    @discardableResult
    public func webSocket(
        _ path: [PathComponent],
        maxFrameSize: WebSocketMaxFrameSize = .`default`,
        onUpgrade: @escaping (Request, WebSocket) -> ()
    ) -> Route {
        return self.on(.GET, path) { request -> Response in
            return request.webSocket(maxFrameSize: maxFrameSize, onUpgrade: onUpgrade)
        }
    }
}
