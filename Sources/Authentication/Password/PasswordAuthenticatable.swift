import Async
import Bits
import Fluent

/// Authenticatable by Basic username:password auth.
public protocol PasswordAuthenticatable: Authenticatable {
    /// Key path to the username
    typealias UsernameKey = ReferenceWritableKeyPath<Self, String>

    /// The key under which the user's username,
    /// email, or other identifing value is stored.
    static var usernameKey: UsernameKey { get }

    /// Key path to the password
    typealias PasswordKey = ReferenceWritableKeyPath<Self, String>

    /// The key under which the user's password
    /// is stored.
    static var passwordKey: PasswordKey { get }
}

extension PasswordAuthenticatable {
    /// Accesses the model's password
    public var authPassword: String {
        get { return self[keyPath: Self.passwordKey] }
        set { self[keyPath: Self.passwordKey] = newValue }
    }

    /// Accesses the model's username
    public var authUsername: String {
        get { return self[keyPath: Self.usernameKey] }
        set { self[keyPath: Self.usernameKey] = newValue }
    }
}
