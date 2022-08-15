extension Request {
    /// Helper for accessing authenticated objects.
    /// See `Authenticator` for more information.
    public var auth: Authentication {
        return .init(request: self)
    }

    /// Request helper for storing and fetching authenticated objects.
    public struct Authentication {
        let request: Request
        init(request: Request) {
            self.request = request
        }
    }
}

extension Request.Authentication {
    /// Authenticates the supplied instance for this request.
    @available(*, deprecated, message: "To ensure thread safety, migrate to the async API")
    public func login<A>(_ instance: A)
        where A: Authenticatable
    {
        self.legacyCache[A.self] = instance
    }

    /// Unauthenticates an authenticatable type.
    @available(*, deprecated, message: "To ensure thread safety, migrate to the async API")
    public func logout<A>(_ type: A.Type = A.self)
        where A: Authenticatable
    {
        self.legacyCache[type] = nil
    }

    /// Returns an instance of the supplied type. Throws if no
    /// instance of that type has been authenticated or if there
    /// was a problem.
    @available(*, deprecated, message: "To ensure thread safety, migrate to the async API")
    @discardableResult public func require<A>(_ type: A.Type = A.self) throws -> A
        where A: Authenticatable
    {
        guard let a = self.get(A.self) else {
            throw Abort(.unauthorized)
        }
        return a
    }

    /// Returns the authenticated instance of the supplied type.
    /// - note: `nil` if no type has been authed.
    @available(*, deprecated, message: "To ensure thread safety, migrate to the async API")
    public func get<A>(_ type: A.Type = A.self) -> A?
        where A: Authenticatable
    {
        return self.legacyCache[A.self]
    }

    /// Returns `true` if the type has been authenticated.
    @available(*, deprecated, message: "To ensure thread safety, migrate to the async API")
    public func has<A>(_ type: A.Type = A.self) -> Bool
        where A: Authenticatable
    {
        return self.get(A.self) != nil
    }
    
    #if(canImport(_Concurrency))
    public func login<A>(_ instance: A) async
        where A: Authenticatable
    {
        await self.getCache()[A.self] = instance
    }

    /// Unauthenticates an authenticatable type.
    public func logout<A>(_ type: A.Type = A.self) async
        where A: Authenticatable
    {
        await self.getCache()[A.self] = nil
    }

    /// Returns an instance of the supplied type. Throws if no
    /// instance of that type has been authenticated or if there
    /// was a problem.
    @discardableResult public func require<A>(_ type: A.Type = A.self) async throws -> A
        where A: Authenticatable
    {
        guard let a = await self.get(A.self) else {
            throw Abort(.unauthorized)
        }
        return a
    }

    /// Returns the authenticated instance of the supplied type.
    /// - note: `nil` if no type has been authed.
    public func get<A>(_ type: A.Type = A.self) async -> A?
        where A: Authenticatable
    {
        return await self.getCache()[A.self]
    }

    /// Returns `true` if the type has been authenticated.
    public func has<A>(_ type: A.Type = A.self) async -> Bool
        where A: Authenticatable
    {
        return await self.get(A.self) != nil
    }
    #endif

    private final class Cache {
        private var storage: [ObjectIdentifier: Any]

        init() {
            self.storage = [:]
        }

        internal subscript<A>(_ type: A.Type) -> A?
            where A: Authenticatable
            {
            get { return storage[ObjectIdentifier(A.self)] as? A }
            set { storage[ObjectIdentifier(A.self)] = newValue }
        }
    }

    private struct CacheKey: StorageKey {
        typealias Value = Cache
    }
    
    private func getCache() async -> Cache {
        if let existing = await request.asyncStorage.get(CacheKey.self) {
            return existing
        } else {
            let new = Cache()
            await self.request.asyncStorage.set(CacheKey.self, to: new)
            return new
        }
    }

    private var legacyCache: Cache {
        get {
            if let existing = self.request.storage[CacheKey.self] {
                return existing
            } else {
                let new = Cache()
                self.request.storage[CacheKey.self] = new
                return new
            }
        }
        set {
            self.request.storage[CacheKey.self] = newValue
        }
    }
}
