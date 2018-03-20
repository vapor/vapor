/// Handles an `HTTPRequest` requesting to upgrade to the websocket protocol.
///
/// The `WebSocketResponder` can decide to deny the upgrade by returning `nil` on `shouldUpgrade`.
/// In this case, the HTTP request will continue to Vapor's normal request/response chain (invoking middleware).
///
/// If the HTTP request is approved to upgrade, the `onUpgrade` callback will receive the connected websocket client.
public struct WebSocketResponder {
    /// Used to determine whether to upgrade the HTTP request or not.
    /// If the `HTTPHeaders` returned are not nil, the upgrade request is accepted and
    /// `onUpgrade` will be called with the accepted clients.
    internal let shouldUpgrade: (Request) -> HTTPHeaders?

    /// Handles the newly connected websocket client.
    /// This closure is also supplied with the HTTP request that created the connection.
    internal let onUpgrade: (WebSocket, Request) throws -> ()

    /// Creates a new `WebSocketResponder` with closures for handling websocket upgrade events.
    ///
    /// - parameters:
    ///     - shouldUpgrade: Determines whether to upgrade the HTTP request or not.
    ///                      Headers returned by this parameter will be returned with the 101 switching protocols response.
    ///                      If `nil` is returned, the upgrade request will be denied.
    ///     - onUpgrade: Handles the newly connected websocket client when `shouldUpgrade` approves the upgrade request.
    ///                  The HTTP request that initiated the upgrade is also supplied.
    public init(shouldUpgrade: @escaping (Request) -> HTTPHeaders?, onUpgrade: @escaping (WebSocket, Request) throws -> ()) {
        self.shouldUpgrade = shouldUpgrade
        self.onUpgrade = onUpgrade
    }
}
