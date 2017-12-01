import Vapor

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

// MARK: Request

extension Request {
    /// Authenticates the supplied instance for this request.
    public func authenticate<A>(_ instance: A) throws
        where A: Authenticatable
    {
        let cache = try make(AuthenticationCache.self)
        cache[A.self] = instance
    }

    /// Returns the authenticated instance of the supplied type.
    /// note: nil if no type has been authed, throws if there is a problem.
    public func authenticated<A>(_ type: A.Type) throws -> A?
        where A: Authenticatable
    {
        let cache = try make(AuthenticationCache.self)
        return cache[A.self]
    }

    /// Returns true if the type has been authenticated.
    public func isAuthenticated<A>(_ type: A.Type) throws -> Bool
        where A: Authenticatable
    {
        return try authenticated(A.self) != nil
    }

    /// Returns an instance of the supplied type. Throws if no
    /// instance of that type has been authenticated or if there
    /// was a problem.
    public func requireAuthenticated<A>(_ type: A.Type) throws -> A
        where A: Authenticatable
    {
        guard let a = try authenticated(A.self) else {
            throw AuthenticationError(
                identifier: "notAuthenticated",
                reason: "\(A.self) has not been authenticated."
            )
        }
        return a
    }
}
