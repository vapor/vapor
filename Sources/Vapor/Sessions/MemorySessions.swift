/// Simple in-memory sessions implementation.
public final class MemorySessions: Sessions, Service {
    /// Actual implementation.
    private let keyedCacheSessions: KeyedCacheSessions

    /// Create a new `MemorySessions` with the supplied cookie factory.
    public init() {
        self.keyedCacheSessions = KeyedCacheSessions(keyedCache: MemoryKeyedCache())
    }

    /// See `Sessions`.
    public func createSession(_ session: Session) throws -> Future<Void> {
        return try keyedCacheSessions.createSession(session)
    }

    /// See `Sessions`.
    public func readSession(sessionID: String) throws -> Future<Session?> {
        return try keyedCacheSessions.readSession(sessionID: sessionID)
    }

    /// See `Sessions`.
    public func updateSession(_ session: Session) throws -> Future<Void> {
        return try keyedCacheSessions.updateSession(session)
    }

    /// See `Sessions`.
    public func destroySession(sessionID: String) throws -> Future<Void> {
        return try keyedCacheSessions.destroySession(sessionID: sessionID)
    }
}
