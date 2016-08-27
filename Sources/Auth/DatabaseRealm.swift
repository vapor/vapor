import Turnstile
import TurnstileWeb
import TurnstileCrypto
import Fluent

public protocol User: Entity, Account {
    init()
}

extension User {
    public var accountID: String {
        return id?.string ?? ""
    }

    public var realm: Realm.Type {
        return DatabaseRealm<Self>.self
    }
}

public class DatabaseRealm<U: User>: Realm {
    public init(_ u: U.Type = U.self) { }

    public func authenticate(credentials: Credentials) throws -> Account {
        if let apikey = credentials as? APIKey {
            print("Authenticating user with creds: \(apikey.id):\(apikey.secret)")
        } else {
            print("Unsupported credentials.")
        }
        return U()
    }
}
