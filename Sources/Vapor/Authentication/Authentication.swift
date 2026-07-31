import HTTPTypes
import Synchronization

extension Request {
    /// Stores and fetches the instances authenticated for a request.
    ///
    /// Owned by the ``Request`` and shared for its whole lifetime, so an instance logged in by an
    /// inner middleware stays visible to an outer middleware as the response unwinds — that is how
    /// ``SessionAuthenticator`` persists a user authenticated further down the chain. Reading has no
    /// side effects.
    /// 
    /// See ``RequestAuthenticator`` for more information.
    public final class Authentication: Sendable {
        let storage = Mutex<AuthenticationStorage>(.init())
    }
}

extension Request.Authentication {
    /// Authenticates the supplied instance for this request.
    ///
    /// Instances are keyed by their static type, so authenticating more than one type at a time is
    /// supported — a bearer token authenticator can log in both the token and the user it belongs to.
    public func login<A: Authenticatable>(_ instance: A) {
        self.storage.withLock { $0.insert(instance) }
    }

    /// Unauthenticates an authenticatable type.
    public func logout<A: Authenticatable>(_ type: A.Type = A.self) {
        self.storage.withLock { $0.remove(A.self) }
    }

    /// Look up an instance of the supplied type, treating it as an error if there is no such instance.
    ///
    /// - Parameter type: The authenticatable type to look up.
    /// - Returns: An instance of the requested type, if one exists.
    /// - Throws: `Abort(.unauthorized)` if no instance of the requested type is available.
    @discardableResult
    public func require<A: Authenticatable>(_ type: A.Type = A.self) throws(Abort) -> A {
        guard let a = self.get(A.self) else {
            throw Abort(.unauthorized)
        }
        return a
    }

    /// Returns the authenticated instance of the supplied type.
    ///
    /// > Note: `nil` if no type has been authenticated.
    public func get<A: Authenticatable>(_ type: A.Type = A.self) -> A? {
        self.storage.withLock { $0.value(A.self) }
    }

    /// Returns `true` if the type has been authenticated.
    public func has<A: Authenticatable>(_ type: A.Type = A.self) -> Bool {
        self.storage.withLock { $0.contains(A.self) }
    }
}

/// The actual storage for the request's authentication. Uses an array instead of a dictionary as
/// this was more performant with a small number of entries
struct AuthenticationStorage: Sendable {
    private var entries: [(key: ObjectIdentifier, value: any Authenticatable)] = []

    func value<A: Authenticatable>(_ type: A.Type) -> A? {
        let key = ObjectIdentifier(A.self)
        return self.entries.first { $0.key == key }?.value as? A
    }

    /// Cheaper than `value(_:) != nil` because it doesn't need the dynamic cast
    func contains<A: Authenticatable>(_ type: A.Type) -> Bool {
        let key = ObjectIdentifier(A.self)
        return self.entries.contains { $0.key == key }
    }

    mutating func insert<A: Authenticatable>(_ instance: A) {
        let key = ObjectIdentifier(A.self)
        if let index = self.entries.firstIndex(where: { $0.key == key }) {
            self.entries[index].value = instance
        } else {
            self.entries.append((key, instance))
        }
    }

    mutating func remove<A: Authenticatable>(_ type: A.Type) {
        let key = ObjectIdentifier(A.self)
        self.entries.removeAll { $0.key == key }
    }
}
