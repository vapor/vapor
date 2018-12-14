/// A context for the currently running `Server` protocol. When a `Server` successfully boots,
/// it sets one of these on the `runningServer` property of the `Application`.
///
/// This struct can be used to close the server.
///
///     try app.runningServer?.close().wait()
///
/// It can also be used to wait until something else closes the server.
///
///     try app.runningServer?.onClose().wait()
///
public struct RunningServer {
    /// A future that will be completed when the server closes.
    public let onClose: EventLoopFuture<Void>

    /// Stops the currently running server, if one is running.
    public let close: () -> EventLoopFuture<Void>
}
