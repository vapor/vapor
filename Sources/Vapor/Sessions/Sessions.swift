/// Capable of managing CRUD operations for `Session`s.
public protocol Sessions {
    var eventLoop: EventLoop { get }
    
    /// Stores a newly created `Session`.
    ///
    /// - parameters:
    ///     - session: New `Session` to create.
    /// - returns: A `Future` that will be completed when the operation has finished.
    func createSession(_ session: Session) -> EventLoopFuture<Void>

    /// Fetches a session for the supplied cookie value.
    ///
    /// - parameters:
    ///     - sessionID: `String` identifier of the `Session` to fetch.
    /// - returns: `Session` if found, `nil` if none exists.
    func readSession(sessionID: String) -> EventLoopFuture<Session?>

    /// Updates the session. Call before the response with the session cookie is returned.
    ///
    /// - parameters:
    ///     - session: Existing `Session` to update.
    /// - returns: A `Future` that will be completed when the operation has finished.
    func updateSession(_ session: Session) -> EventLoopFuture<Void>

    /// Destroys the session. Call if the response is no longer valid.
    ///
    /// - parameters:
    ///     - sessionID: `String` identifier of the `Session` to destroy.
    /// - returns: A `Future` that will be completed when the operation has finished.
    func destroySession(sessionID: String) -> EventLoopFuture<Void>
}
