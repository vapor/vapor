import HTTPTypes
import Synchronization

extension Request {
    /// Helper for accessing authenticated objects.
    ///
    /// See ``RequestAuthenticator`` for more information.
    public var auth: Authentication {
        .init(cell: self.authenticationCell)
    }

    /// Request helper for storing and fetching authenticated objects.
    ///
    /// This is a lightweight view onto storage owned by the ``Request``, so an instance logged in by
    /// an inner middleware is visible to outer middleware as the response unwinds, and reading has
    /// no side effects.
    public struct Authentication: Sendable {
        let cell: AuthenticationCell

        init(cell: AuthenticationCell) {
            self.cell = cell
        }
    }
}

extension Request.Authentication {
    public func login<A: Authenticatable>(_ instance: A) {
        self.cell.storage.withLock { $0.insert(instance) }
    }

    public func logout<A: Authenticatable>(_ type: A.Type = A.self) {
        self.cell.storage.withLock { $0.remove(A.self) }
    }

    @discardableResult
    public func require<A: Authenticatable>(_ type: A.Type = A.self) throws -> A {
        guard let a = self.get(A.self) else {
            throw Abort(.unauthorized)
        }
        return a
    }

    public func get<A: Authenticatable>(_ type: A.Type = A.self) -> A? {
        self.cell.storage.withLock { $0.value(A.self) }
    }

    public func has<A: Authenticatable>(_ type: A.Type = A.self) -> Bool {
        self.cell.storage.withLock { $0.contains(A.self) }
    }
}

/// Reference-typed backing store for ``Request/auth``.
///
/// Held by the ``Request`` rather than kept in a task local, because a login performed by an inner
/// middleware has to remain visible to an outer middleware after `next.respond(to:)` returns — that
/// is how ``SessionAuthenticator`` persists a user authenticated further down the chain. A task
/// local, being restored when its scope exits, cannot carry a value outwards.
final class AuthenticationCell: Sendable {
    let storage = Mutex<AuthenticationStorage>(.init())
}

/// This storage uses an array instead of a dictionary as it was more performant for a small number of entries
/// like we normally have
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
