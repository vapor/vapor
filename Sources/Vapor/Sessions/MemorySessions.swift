/// Simple in-memory sessions implementation.
public final class MemorySessions: Sessions {
    /// Actual implementation.
    private var cache: [String: Session]
    
    public let eventLoop: EventLoop

    /// Create a new `MemorySessions` with the supplied cookie factory.
    public init(on eventLoop: EventLoop) {
        self.cache = [:]
        self.eventLoop = eventLoop
    }

    /// Stores a newly created `Session`.
    ///
    /// - parameters:
    ///     - session: New `Session` to create.
    /// - returns: A `Future` that will be completed when the operation has finished.
    public func createSession(_ session: Session) -> EventLoopFuture<Void> {
        return self.eventLoop.makeSucceededFuture(result: ())
    }
    
    /// Fetches a session for the supplied cookie value.
    ///
    /// - parameters:
    ///     - sessionID: `String` identifier of the `Session` to fetch.
    /// - returns: `Session` if found, `nil` if none exists.
    public func readSession(sessionID: String) -> EventLoopFuture<Session?> {
        return self.eventLoop.makeSucceededFuture(result: self.cache[sessionID])
    }
    
    /// Updates the session. Call before the response with the session cookie is returned.
    ///
    /// - parameters:
    ///     - session: Existing `Session` to update.
    /// - returns: A `Future` that will be completed when the operation has finished.
    public func updateSession(_ session: Session) -> EventLoopFuture<Void> {
        self.cache[session.id!] = session
        return self.eventLoop.makeSucceededFuture(result: ())
    }
    
    /// Destroys the session. Call if the response is no longer valid.
    ///
    /// - parameters:
    ///     - sessionID: `String` identifier of the `Session` to destroy.
    /// - returns: A `Future` that will be completed when the operation has finished.
    public func destroySession(sessionID: String) -> EventLoopFuture<Void> {
        self.cache[sessionID] = nil
        return self.eventLoop.makeSucceededFuture(result: ())
    }
}
