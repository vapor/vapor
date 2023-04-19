import NIOCore
import NIOHTTP1
import WebSocketKit
import RoutingKit
import Foundation

extension Request {

    /// Upgrades an existing request to a websocket connection
    public func webSocket(
        maxFrameSize: WebSocketMaxFrameSize = .`default`,
        shouldUpgrade: @escaping (@Sendable (Request) async throws -> HTTPHeaders?) = { _ in [:] },
        onUpgrade: @Sendable @escaping (Request, WebSocket) async -> ()
    ) -> Response {
        webSocket(
            maxFrameSize: maxFrameSize,
            shouldUpgrade: { request in
                let promise = request.eventLoop.makePromise(of: HTTPHeaders?.self)
                promise.completeWithTask {
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
        shouldUpgrade: @escaping (@Sendable (Request) async throws -> HTTPHeaders?) = { _ in [:] },
        onUpgrade: @Sendable @escaping (Request, WebSocket) async -> ()
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
        shouldUpgrade: @escaping (@Sendable (Request) async throws -> HTTPHeaders?) = { _ in [:] },
        onUpgrade: @Sendable @escaping (Request, WebSocket) async -> ()
    ) -> Route {
        return self.on(.GET, path) { request -> Response in
            return request.webSocket(maxFrameSize: maxFrameSize, shouldUpgrade: shouldUpgrade, onUpgrade: onUpgrade)
        }
    }
}

extension WebSocket {
    public static func connect(
        to url: String,
        headers: HTTPHeaders = [:],
        configuration: WebSocketClient.Configuration = .init(),
        on eventLoopGroup: EventLoopGroup,
        onUpgrade: @Sendable @escaping (WebSocket) -> ()
    ) async throws {
        guard let url = URL(string: url) else {
            throw WebSocketClient.Error.invalidURL
        }
        return try await self.connect(
            to: url,
            headers: headers,
            configuration: configuration,
            on: eventLoopGroup,
            onUpgrade: onUpgrade
        )
    }

    public static func connect(
        to url: URL,
        headers: HTTPHeaders = [:],
        configuration: WebSocketClient.Configuration = .init(),
        on eventLoopGroup: EventLoopGroup,
        onUpgrade: @escaping @Sendable (WebSocket) -> ()
    ) async throws  {
        let scheme = url.scheme ?? "ws"
        return try await self.connect(
            scheme: scheme,
            host: url.host ?? "localhost",
            port: url.port ?? (scheme == "wss" ? 443 : 80),
            path: url.path,
            headers: headers,
            configuration: configuration,
            on: eventLoopGroup,
            onUpgrade: onUpgrade
        )
    }

    public static func connect(
        scheme: String = "ws",
        host: String,
        port: Int = 80,
        path: String = "/",
        headers: HTTPHeaders = [:],
        configuration: WebSocketClient.Configuration = .init(),
        on eventLoopGroup: EventLoopGroup,
        onUpgrade: @escaping @Sendable (WebSocket) -> ()
    ) async throws  {
        return try await WebSocketClient(
            eventLoopGroupProvider: .shared(eventLoopGroup),
            configuration: configuration
        ).connect(
            scheme: scheme,
            host: host,
            port: port,
            path: path,
            headers: headers,
            onUpgrade: onUpgrade
        ).get()
    }
}
