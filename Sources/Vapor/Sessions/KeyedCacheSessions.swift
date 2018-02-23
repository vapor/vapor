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

    public func readSession(for cookie: Cookie.Value) throws -> Future<Session?> {
        return try keyedCache.get(SessionData.self, forKey: cookie.value).map(to: Session?.self) { data in
            return data.flatMap { Session(cookie: cookie, data: $0) }
        }
    }

    public func updateSession(_ session: Session) throws -> Future<Cookie.Value> {
        let cookie: Cookie.Value
        if let existing = session.cookie {
            cookie = existing
        } else {
            /// FIXME: optimize
            let random = Base64Encoder().encode(data: OSRandom().data(count: 16))
            cookie = config.cookieFactory(String(data: random, encoding: .utf8)!)
        }
        session.cookie = cookie
        return try keyedCache.set(session.data, forKey: cookie.value).transform(to: cookie)
    }

    public func destroySession(for cookie: Cookie.Value) throws -> Future<Void> {
        return try keyedCache.remove(cookie.value)
    }
}

extension KeyedCacheSessions: ServiceType {
    /// See `ServiceType.serviceSupports(for:)`
    public static var serviceSupports: [Any.Type] { return [Sessions.self] }

    /// See `ServiceType.makeService(for:)`
    public static func makeService(for worker: Container) throws -> KeyedCacheSessions {
        return try .init(
            keyedCache: worker.make(for: KeyedCacheSessions.self),
            config: worker.make(for: KeyedCacheSessions.self)
        )
    }
}
