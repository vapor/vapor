/// SwiftNIO based `WebSocketClient`.
public final class NIOWebSocketClient: ServiceType, WebSocketClient {
    /// See `ServiceType`.
    public static var serviceSupports: [Any.Type] { return [WebSocketClient.self] }

    /// See `ServiceType`.
    public static func makeService(for worker: Container) throws -> NIOWebSocketClient {
        return .init()
    }

    /// Creates a new `NIOWebSocketClient`.
    public init() { }

    /// See `WebSocketClient`.
    public func webSocketConnect(_ request: Request) -> Future<WebSocket> {
        guard let hostname = request.http.url.host else {
            let error = VaporError(identifier: "webSocketHostname", reason: "Missing WebSocket hostname: \(request.http.url).")
            return request.eventLoop.newFailedFuture(error: error)
        }
        guard let scheme = request.http.url.scheme else {
            let error = VaporError(identifier: "webSocketScheme", reason: "Missing WebSocket scheme: \(request.http.url).")
            return request.eventLoop.newFailedFuture(error: error)
        }
        let httpScheme: HTTPScheme
        switch scheme {
        case "http", "ws": httpScheme = .ws
        case "https", "wss": httpScheme = .wss
        default:
            let error = VaporError(identifier: "webSocketSchemeType", reason: "Unsupported WebSocket scheme: \(scheme).")
            return request.eventLoop.newFailedFuture(error: error)
        }
        let path = request.http.url.path.isEmpty ? "/" : request.http.url.path
        return HTTPClient.webSocket(scheme: httpScheme, hostname: hostname, port: request.http.url.port, path: path, on: request)
    }
}
