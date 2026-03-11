import NIOConcurrencyHelpers

/// A thread-safe, generic collection of values keyed by ID.
public final class Registry<ID: Hashable & Sendable, Value: Sendable>: Sendable {
    private let entries: NIOLockedValueBox<[ID: Value]>

    public init() {
        self.entries = .init([:])
    }

    public func register(_ id: ID, _ value: Value) {
        self.entries.withLockedValue { $0[id] = value }
    }

    @discardableResult
    public func remove(_ id: ID) -> Value? {
        self.entries.withLockedValue { $0.removeValue(forKey: id) }
    }

    public subscript(id: ID) -> Value? {
        self.entries.withLockedValue { $0[id] }
    }

    public var all: [ID: Value] {
        self.entries.withLockedValue { $0 }
    }

    public var count: Int {
        self.entries.withLockedValue { $0.count }
    }

    public var isEmpty: Bool {
        self.entries.withLockedValue { $0.isEmpty }
    }

    public func contains(_ id: ID) -> Bool {
        self.entries.withLockedValue { $0[id] != nil }
    }

    /// Throws ``RegistryError/notFound`` if no value exists for the given ID.
    public func send(to id: ID, _ action: @Sendable (Value) async throws -> Void) async throws {
        guard let value = self[id] else {
            throw RegistryError.notFound
        }
        try await action(value)
    }

    /// Snapshots the registry before iterating so mutations during iteration are safe.
    public func broadcast(_ action: @Sendable (Value) async throws -> Void) async throws {
        let snapshot = self.all
        for value in snapshot.values {
            try await action(value)
        }
    }

    public func clear() {
        self.entries.withLockedValue { $0.removeAll() }
    }
}

public enum RegistryError: Error, CustomStringConvertible {
    case notFound

    public var description: String {
        switch self {
        case .notFound:
            return "Registry entry not found for the given ID."
        }
    }
}
