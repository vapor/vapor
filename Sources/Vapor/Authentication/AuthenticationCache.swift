/// Stores authenticated objects. This should be created
/// using the request container as a singleton. Authenticated
/// objects can then be stored here by middleware and fetched
/// later in route closures.
final class AuthenticationCache {
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

extension BCryptDigest: PasswordVerifier { }

// MARK: Request

extension Request {
    /// Returns an instance of the supplied type. Throws if no
    /// instance of that type has been authenticated or if there
    /// was a problem.
    public func requireAuthenticated<A>(_ type: A.Type = A.self) throws -> A
        where A: Authenticatable
    {
        guard let a = authenticated(A.self) else {
            self.logger.error("\(A.self) has not been authorized")
            throw Abort(.unauthorized)
        }
        return a
    }

    /// Authenticates the supplied instance for this request.
    public func authenticate<A>(_ instance: A)
        where A: Authenticatable
    {
        self._authenticationCache[A.self] = instance
    }

    /// Returns the authenticated instance of the supplied type.
    /// note: nil if no type has been authed, throws if there is a problem.
    public func authenticated<A>(_ type: A.Type = A.self) -> A?
        where A: Authenticatable
    {
        return self._authenticationCache[A.self]
    }

    /// Unauthenticates an authenticatable type.
    public func unauthenticate<A>(_ type: A.Type = A.self)
        where A: Authenticatable
    {
        self._authenticationCache[A.self] = nil
    }

    /// Returns true if the type has been authenticated.
    public func isAuthenticated<A>(_ type: A.Type = A.self) -> Bool
        where A: Authenticatable
    {
        return self.authenticated(A.self) != nil
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
