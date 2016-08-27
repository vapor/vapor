import Fluent
import Turnstile

public protocol User: Entity, Account, Authenticator { }

extension User {
    public var accountID: String {
        return id?.string ?? ""
    }

    public var realm: Realm.Type {
        return AuthenticatorRealm<Self>.self
    }
}
