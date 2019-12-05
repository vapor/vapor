extension Request {
    public var auth: Auth {
        return .init(request: self)
    }

    public struct Auth {
        let request: Request
        init(request: Request) {
            self.request = request
        }
    }
}

extension Request.Auth {
    // MARK: Authenticate

    /// Authenticates the supplied instance for this request.
    public func login<A>(_ instance: A)
        where A: Authenticatable
    {
        self.request._authenticationCache[A.self] = instance
    }

    /// Unauthenticates an authenticatable type.
    public func logout<A>(_ type: A.Type = A.self)
        where A: Authenticatable
    {
        self.request._authenticationCache[A.self] = nil
    }

    // MARK: Verify

    /// Returns an instance of the supplied type. Throws if no
    /// instance of that type has been authenticated or if there
    /// was a problem.
    public func require<A>(_ type: A.Type = A.self) throws -> A
        where A: Authenticatable
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
        where A: Authenticatable
    {
        return self.request._authenticationCache[A.self]
    }

    /// Returns true if the type has been authenticated.
    public func has<A>(_ type: A.Type = A.self) -> Bool
        where A: Authenticatable
    {
        return self.get(A.self) != nil
    }
}

// Internal auth cache

extension Request {
    /// Stores authenticated objects. This should be created
    /// using the request container as a singleton. Authenticated
    /// objects can then be stored here by middleware and fetched
    /// later in route closures.
    internal final class AuthenticationCache {
        /// The internal storage.
        private var storage: [ObjectIdentifier: Any]

        /// Create a new authentication cache.
        init() {
            self.storage = [:]
        }

        /// Access the cache using types.
        internal subscript<A>(_ type: A.Type) -> A?
            where A: Authenticatable
            {
            get { return storage[ObjectIdentifier(A.self)] as? A }
            set { storage[ObjectIdentifier(A.self)] = newValue }
        }
    }

    internal var _authenticationCache: AuthenticationCache {
        get {
            if let existing = self.userInfo[_authenticationCacheKey] as? AuthenticationCache {
                return existing
            } else {
                let new = AuthenticationCache()
                self.userInfo[_authenticationCacheKey] = new
                return new
            }
        }
        set {
            self.userInfo[_authenticationCacheKey] = newValue
        }
    }
}

private let _authenticationCacheKey = "authc"
