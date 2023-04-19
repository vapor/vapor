import Logging
import NIOConcurrencyHelpers

/// A container providing arbitrary storage for extensions of an existing type, designed to obviate
/// the problem of being unable to add stored properties to a type in an extension. Each stored item
/// is keyed by a type conforming to ``StorageKey`` protocol.
/// This type has reference semantics with the use of ``NIOLockedValueBox``
public struct Storage: Sendable {
    /// The internal storage area.
    private let storage: NIOLockedValueBox<[ObjectIdentifier: AnyStorageValue]>

    /// A container for a stored value and an associated optional `deinit`-like closure.
    struct Value<T: Sendable>: AnyStorageValue, Sendable {
        var value: T
        var onShutdown: (@Sendable (T) throws -> ())?
        func shutdown(logger: Logger) {
            do {
                try self.onShutdown?(self.value)
            } catch {
                logger.warning("Could not shutdown \(T.self): \(error)")
            }
        }
    }
    
    /// The logger provided to shutdown closures.
    private let logger: Logger

    /// Create a new ``Storage`` container using the given logger.
    public init(logger: Logger = .init(label: "codes.vapor.storage")) {
        self.storage = .init([:])
        self.logger = logger
    }

    /// Delete all values from the container. Does _not_ invoke shutdown closures.
    public func clear() {
        self.storage.withLockedValue { $0 = [:] }
    }

    /// Read/write access to values via keyed subscript.
    public subscript<Key>(_ key: Key.Type) -> Key.Value?
        where Key: StorageKey
    {
        get {
            self.get(Key.self)
        }
        set {
            self.set(Key.self, to: newValue)
        }
    }

    /// Read access to a value via keyed subscript, adding the provided default
    /// value to the storage if the key does not already exist. Similar to
    /// ``Swift/Dictionary/subscript(key:default:)``. The `defaultValue` autoclosure
    /// is evaluated only when the key does not already exist in the container.
    public subscript<Key>(_ key: Key.Type, default defaultValue: @autoclosure () -> Key.Value) -> Key.Value
        where Key: StorageKey
    {
        nonmutating get {
            if let existing = self[key] { return existing }
            let new = defaultValue()
            self.set(Key.self, to: new)
            return new
        }
    }

    /// Test whether the given key exists in the container.
    public func contains<Key>(_ key: Key.Type) -> Bool {
        self.storage.withLockedValue { $0.keys.contains(ObjectIdentifier(Key.self)) }
    }

    /// Get the value of the given key if it exists and is of the proper type.
    public func get<Key>(_ key: Key.Type) -> Key.Value?
        where Key: StorageKey
    {
        return self.storage.withLockedValue {
            guard let value = $0[ObjectIdentifier(Key.self)] as? Value<Key.Value> else {
                return nil
            }
            return value.value
        }
    }

    /// Set or remove a value for a given key, optionally providing a shutdown closure for the value.
    ///
    /// If a key that has a shutdown closure is removed by this method, the closure **is** invoked.
    public nonmutating func set<Key>(
        _ key: Key.Type,
        to value: Key.Value?,
        onShutdown: (@Sendable (Key.Value) throws -> ())? = nil
    )
        where Key: StorageKey
    {
        let key = ObjectIdentifier(Key.self)
        self.storage.withLockedValue { storageBox in
            if let value = value {
                storageBox[key] = Value(value: value, onShutdown: onShutdown)
            } else if let existing = storageBox[key] {
                storageBox[key] = nil
                existing.shutdown(logger: self.logger)
            }
        }
    }

    /// For every key in the container having a shutdown closure, invoke the closure. Designed to
    /// be invoked during an explicit app shutdown process or in a reference type's `deinit`.
    public func shutdown() {
        let values = self.storage.withLockedValue { $0.values }
        values.forEach {
            $0.shutdown(logger: self.logger)
        }
    }
}

/// ``Storage`` uses this protocol internally to generically invoke shutdown closures for arbitrarily-
/// typed key values.
protocol AnyStorageValue: Sendable {
    func shutdown(logger: Logger)
}

/// A key used to store values in a ``Storage`` must conform to this protocol.
public protocol StorageKey: Sendable {
    /// The type of the stored value associated with this key type.
    associatedtype Value: Sendable
}
