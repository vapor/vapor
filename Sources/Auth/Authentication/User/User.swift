import Fluent
import Turnstile

public protocol User: Entity, Account, Authenticator { }

extension User {
    public var uniqueID: String {
        return id?.string ?? ""
    }
}
