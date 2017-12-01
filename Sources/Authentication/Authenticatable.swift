import Fluent
import Vapor

/// Capable of being authenticated.
/// note: This protocol is extended by other protocols
/// like PasswordAuthenticatable.
public protocol Authenticatable: Model { }



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
