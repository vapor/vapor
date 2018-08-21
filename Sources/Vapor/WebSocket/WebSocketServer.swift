/// A `WebSocketServer` determines whether HTTP requests requesting upgrade to the websocket protocol should
/// be approved or denied. If approved, additional headers can be returned in the 101 switching protocols response.
///
/// When HTTP upgrade requests are approved, the `WebSocketServer` will handle the newly connected websocket clients.
///
/// HTTP upgrade requests will be handled by the `WebSocketServer` before invoking Vapor's normal HTTP request pipeline
/// (including middleware). Should an HTTP upgrade request be accepted, no other parts of Vapor's pipeline will be invoked.
/// Should the HTTP upgrade request be denied, the request will continue through Vapor's HTTP pipeline normally.
///
/// Note: The `WebSocketServer` _always_ runs behind an HTTP server and will only be invoked when HTTP requests request an upgrade.
public protocol WebSocketServer {
    /// Determines whether the HTTP request should be upgraded or not.
    /// Only HTTP requests that have requested websocket protocol upgrade will be supplied to this method.
    ///
    /// - parameters:
    ///     - request: The HTTP request requesting upgrade to websocket protocol.
    /// - returns: HTTPHeaders to include in the 101 switching protocols HTTP response.
    ///            If `nil`, the HTTP upgrade request will be denied.
    func webSocketShouldUpgrade(for request: Request) -> HTTPHeaders?

    /// Handles newly connected websocket clients. This method will only be called if `webSocketShouldUpgrade(for:)` returned
    /// non-nil HTTP headers.
    ///
    /// - parameters:
    ///     - webSocket: The newly connected websocket client. Use this to send and receive messages from the client.
    ///     - request: The HTTP request that initiated the websocket protocol upgrade.
    func webSocketOnUpgrade(_ webSocket: WebSocket, for request: Request)
}
