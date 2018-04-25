import CacheKit
import Crypto

/// `Sessions` protocol implemented by a `KeyedCache`.
public final class KeyedCacheSessions: Sessions {
    /// The underlying `KeyedCache` this class uses to implement
    /// the `Sessions` protocol.
    public let keyedCache: KeyedCache

    /// The session config options.
    public let config: SessionsConfig

    /// Creates a new `KeyedCacheSessions`
    public init(keyedCache: KeyedCache, config: SessionsConfig) {
        self.keyedCache = keyedCache
        self.config = config
    }

    public func readSession(sessionID: String) throws -> Future<Session?> {
        return keyedCache.get(sessionID, as: SessionData.self).map(to: Session?.self) { data in
            return data.flatMap { Session(id: sessionID, data: $0) }
        }
    }

    public func updateSession(_ session: Session) throws -> Future<Session> {
        let sessionID: String
        if let existing = session.id {
            sessionID = existing
        } else {
            sessionID = try CryptoRandom().generateData(count: 16).base64EncodedString()
        }
        session.id = sessionID
        return keyedCache.set(sessionID, to: session.data).transform(to: session)
    }

    public func destroySession(sessionID: String) throws -> Future<Void> {
        return keyedCache.remove(sessionID)
    }
}

extension KeyedCacheSessions: ServiceType {
    /// See `ServiceType.serviceSupports(for:)`
    public static var serviceSupports: [Any.Type] { return [Sessions.self] }

    /// See `ServiceType.makeService(for:)`
    public static func makeService(for worker: Container) throws -> KeyedCacheSessions {
        return try .init(
            keyedCache: worker.make(),
            config: worker.make()
        )
    }
}

