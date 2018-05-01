/// Servers are capable of binding to an address and subsequently responding to requests sent to that address.
public protocol Server {
    /// Starts the `Server`.
    ///
    /// Upon starting, the `Server` must set the application's `runningServer` property.
    ///
    /// - parameters:
    ///     - hostname: Optional hostname override.
    ///                 If set, the server should bind to this hostname instead of its configured hostname.
    ///     - port: Optional port override.
    ///             If set, the server should bind to this port instead of its configured port.
    /// - returns: A future notification that will complete when the `Server` has started successfully.
    func start(hostname: String?, port: Int?) -> Future<Void>
}
