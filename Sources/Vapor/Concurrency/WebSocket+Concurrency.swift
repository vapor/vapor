#if compiler(>=5.5)
import _NIOConcurrency

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension Request {

    /// Upgrades an existing request to a websocket connection
    public func webSocket(
        maxFrameSize: WebSocketMaxFrameSize = .`default`,
        shouldUpgrade: @escaping ((Request) async throws -> HTTPHeaders?) = { _ in [:] },
        onUpgrade: @escaping (Request, WebSocket) async -> ()
    ) -> Response {
        webSocket(
            maxFrameSize: maxFrameSize,
            shouldUpgrade: { request in
                let promise = request.eventLoop.makePromise(of: HTTPHeaders?.self)
                promise.completeWithAsync {
                    try await shouldUpgrade(request)
                }
                return promise.futureResult
            },
            onUpgrade: { request, socket in
                Task {
                    await onUpgrade(request, socket)
                }
            }
        )
    }
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension RoutesBuilder {

    /// Adds a route for opening a web socket connection
    /// - parameters:
    ///   - path: Path components separated by commas.
    ///   - maxFrameSize: The maximum allowed frame size. See `NIOWebSocketServerUpgrader`.
    ///   - shouldUpgrade: Closure to apply before upgrade to web socket happens.
    ///       Returns additional `HTTPHeaders` for response, `nil` to deny upgrading.
    ///       See `NIOWebSocketServerUpgrader`.
    ///   - onUpgrade: Closure to apply after web socket is upgraded successfully.
    /// - returns: `Route` instance for newly created web socket endpoint
    @discardableResult
    public func webSocket(
        _ path: PathComponent...,
        maxFrameSize: WebSocketMaxFrameSize = .`default`,
        shouldUpgrade: @escaping ((Request) async throws -> HTTPHeaders?) = { _ in [:] },
        onUpgrade: @escaping (Request, WebSocket) async -> ()
    ) -> Route {
        return self.webSocket(path, maxFrameSize: maxFrameSize, shouldUpgrade: shouldUpgrade, onUpgrade: onUpgrade)
    }

    /// Adds a route for opening a web socket connection
    /// - parameters:
    ///   - path: Array of path components.
    ///   - maxFrameSize: The maximum allowed frame size. See `NIOWebSocketServerUpgrader`.
    ///   - shouldUpgrade: Closure to apply before upgrade to web socket happens.
    ///       Returns additional `HTTPHeaders` for response, `nil` to deny upgrading.
    ///       See `NIOWebSocketServerUpgrader`.
    ///   - onUpgrade: Closure to apply after web socket is upgraded successfully.
    /// - returns: `Route` instance for newly created web socket endpoint
    @discardableResult
    public func webSocket(
        _ path: [PathComponent],
        maxFrameSize: WebSocketMaxFrameSize = .`default`,
        shouldUpgrade: @escaping ((Request) async throws -> HTTPHeaders?) = { _ in [:] },
        onUpgrade: @escaping (Request, WebSocket) async -> ()
    ) -> Route {
        return self.on(.GET, path) { request -> Response in
            return request.webSocket(maxFrameSize: maxFrameSize, shouldUpgrade: shouldUpgrade, onUpgrade: onUpgrade)
        }
    }
}
#endif
