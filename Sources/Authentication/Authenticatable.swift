import Fluent
import Vapor

/// Capable of being authenticated.
/// note: This protocol is extended by other protocols
/// like PasswordAuthenticatable.
public protocol Authenticatable: Model { }

final class AuthenticationCache {
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

extension Request {
    public func authenticate<A>(_ instance: A) throws
        where A: Authenticatable
    {
        let cache = try make(AuthenticationCache.self)
        cache[A.self] = instance
    }

    public func authenticated<A>(_ type: A.Type) throws -> A?
        where A: Authenticatable
    {
        let cache = try make(AuthenticationCache.self)
        return cache[A.self]
    }

    public func isAuthenticated<A>(_ type: A.Type) throws -> Bool
        where A: Authenticatable
    {
        return try authenticated(A.self) != nil
    }

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

import Crypto

/// A struct password verifier around bcrypt
public final class BCryptVerifier: PasswordVerifier {
    /// Create a new bcrypt verifier
    public init() {}

    /// See PasswordVerifier.verify
    public func verify(password: String, matches hash: String) throws -> Bool {
        return try BCrypt.verify(message: password, matches: hash)
    }
}

/// Adds authentication services to a container
public final class AuthenticationProvider: Provider {
    /// See Provider.repositoryName
    public static var repositoryName: String = "auth"

    /// Create a new authentication provider
    public init() { }

    /// See Provider.register
    public func register(_ services: inout Services) throws {
        services.register(PasswordVerifier.self) { container in
            return BCryptVerifier()
        }
        services.register(isSingleton: true) { container in
            return AuthenticationCache()
        }
    }

    /// See Provider.boot
    public func boot(_ worker: Container) throws { }
}
