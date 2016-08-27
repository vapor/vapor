import Turnstile

public protocol Authenticator {
    static func authenticate(credentials: Credentials) throws -> Account
}
