import Turnstile

public final class AuthenticatorRealm<A: Authenticator>: Realm {
    public init(_ a: A.Type = A.self) { }

    public func authenticate(credentials: Credentials) throws -> Account {
        return try A.authenticate(credentials: credentials)
    }
}
