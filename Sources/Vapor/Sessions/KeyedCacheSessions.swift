import Crypto

/// `Sessions` protocol implemented by a `KeyedCache`.
public final class KeyedCacheSessions: Sessions, ServiceType {
    /// See `ServiceType`.
    public static var serviceSupports: [Any.Type] { return [Sessions.self] }

    /// See `ServiceType`.
    public static func makeService(for worker: Container) throws -> KeyedCacheSessions {
        return try .init(keyedCache: worker.make())
    }

    /// The underlying `KeyedCache` this class uses to implement the `Sessions` protocol.
    public let keyedCache: KeyedCache

    /// Creates a new `KeyedCacheSessions`
    public init(keyedCache: KeyedCache) {
        self.keyedCache = keyedCache
    }

    /// See `Sessions`.
    public func createSession(_ session: Session) throws -> Future<Void> {
        let sessionID = try CryptoRandom().generateData(count: 16).base64EncodedString()
        session.id = sessionID
        return keyedCache.set(sessionID, to: session.data)
    }

    /// See `Sessions`.
    public func readSession(sessionID: String) throws -> Future<Session?> {
        return keyedCache.get(sessionID, as: SessionData.self).map { data in
            return data.flatMap { Session(id: sessionID, data: $0) }
        }
    }

    /// See `Sessions`.
    public func updateSession(_ session: Session) throws -> Future<Void> {
        guard let sessionID = session.id else {
            throw VaporError(identifier: "sessionID", reason: "Cannot update `Session` with `nil` ID.")
        }
        session.id = sessionID
        return keyedCache.set(sessionID, to: session.data)
    }

    /// See `Sessions`.
    public func destroySession(sessionID: String) throws -> Future<Void> {
        return keyedCache.remove(sessionID)
    }
}
