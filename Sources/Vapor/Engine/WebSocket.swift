public protocol WebSocketServer {
    func webSocketShouldUpgrade(for request: Request) -> Bool
    func webSocketOnUpgrade(_ webSocket: WebSocket, for request: Request)
}

public final class EngineWebSocketServer: WebSocketServer, Service {
    private let shouldUpgrade: (Request) -> Bool
    private let onUpgrade: (WebSocket, Request) throws -> ()

    public init(shouldUpgrade: @escaping (Request) -> Bool, onUpgrade: @escaping (WebSocket, Request) throws -> ()) {
        self.shouldUpgrade = shouldUpgrade
        self.onUpgrade = onUpgrade
    }

    public static func `default`(shouldUpgrade: @escaping (Request) -> Bool = { _ in return true }, onUpgrade: @escaping (WebSocket, Request) throws -> ()) -> EngineWebSocketServer {
        return .init(shouldUpgrade: shouldUpgrade, onUpgrade: onUpgrade)
    }

    public func webSocketShouldUpgrade(for request: Request) -> Bool {
        return shouldUpgrade(request)
    }

    public func webSocketOnUpgrade(_ webSocket: WebSocket, for request: Request) {
        do {
            return try onUpgrade(webSocket, request)
        } catch {
            ERROR("WebSocket: \(error)")
            webSocket.close()
        }
    }
}
