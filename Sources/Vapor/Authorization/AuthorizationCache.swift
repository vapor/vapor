extension Request {
    public var authz: Authorization {
        return .init(request: self)
    }

    public struct Authorization {
        let request: Request
        init(request: Request) {
            self.request = request
        }
    }
}

extension Request.Authorization {
    // MARK: Authenticate

    /// Authenticates the supplied instance for this request.
    public func add<A>(_ instance: A)
        where A: Authorizable
    {
        self.cache[A.self] = instance
    }

    /// Unauthenticates an authenticatable type.
    public func remove<A>(_ type: A.Type = A.self)
        where A: Authorizable
    {
        self.cache[A.self] = nil
    }

    // MARK: Verify

    /// Returns an instance of the supplied type. Throws if no
    /// instance of that type has been authenticated or if there
    /// was a problem.
    public func require<A>(_ type: A.Type = A.self) throws -> A
        where A: Authorizable
    {
        guard let a = self.get(A.self) else {
            self.request.logger.error("\(A.self) has not been authorized")
            throw Abort(.unauthorized)
        }
        return a
    }

    /// Returns the authenticated instance of the supplied type.
    /// note: nil if no type has been authed.
    public func get<A>(_ type: A.Type = A.self) -> A?
        where A: Authorizable
    {
        return self.cache[A.self]
    }

    /// Returns true if the type has been authenticated.
    public func has<A>(_ type: A.Type = A.self) -> Bool
        where A: Authorizable
    {
        return self.get(A.self) != nil
    }

    /// Stores authenticated objects. This should be created
    /// using the request container as a singleton. Authenticated
    /// objects can then be stored here by middleware and fetched
    /// later in route closures.
    private final class AuthorizationCache {
        /// The internal storage.
        private var storage: [ObjectIdentifier: Any]

        /// Create a new authentication cache.
        init() {
            self.storage = [:]
        }

        /// Access the cache using types.
        internal subscript<A>(_ type: A.Type) -> A?
            where A: Authorizable
            {
            get { return storage[ObjectIdentifier(A.self)] as? A }
            set { storage[ObjectIdentifier(A.self)] = newValue }
        }
    }

    private var cache: AuthorizationCache {
        get {
            if let existing = self.request.userInfo[_authorizationCacheKey] as? AuthorizationCache {
                return existing
            } else {
                let new = AuthorizationCache()
                self.request.userInfo[_authorizationCacheKey] = new
                return new
            }
        }
        set {
            self.request.userInfo[_authorizationCacheKey] = newValue
        }
    }
}

private let _authorizationCacheKey = "authz"
