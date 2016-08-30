import Turnstile

@_exported import protocol Turnstile.Credentials

public protocol Authenticator {
    static func authenticate(credentials: Credentials) throws -> User
    static func register(credentials: Credentials) throws -> User
}
