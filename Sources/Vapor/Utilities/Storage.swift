import Logging
import NIOConcurrencyHelpers

/// A container providing arbitrary storage for extensions of an existing type, designed to obviate
/// the problem of being unable to add stored properties to a type in an extension. Each stored item
/// is keyed by a type conforming to ``StorageKey`` protocol.
@preconcurrency
public struct Storage: Sendable {
    /// The internal storage area.
    private var storage: [ObjectIdentifier: AnyStorageValue]

    /// A container for a stored value and an associated optional `deinit`-like closure.
    @preconcurrency
    struct Value<T: Sendable>: AnyStorageValue {
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
        self.storage = [:]
        self.logger = logger
    }

    /// Delete all values from the container. Does _not_ invoke shutdown closures.
    public mutating func clear() {
        self.storage = [:]
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
        mutating get {
            if let existing = self[key] { return existing }
            let new = defaultValue()
            self.set(Key.self, to: new)
            return new
        }
    }

    /// Test whether the given key exists in the container.
    public func contains<Key>(_ key: Key.Type) -> Bool {
        return self.storage.keys.contains(ObjectIdentifier(Key.self))
    }

    /// Get the value of the given key if it exists and is of the proper type.
    public func get<Key>(_ key: Key.Type) -> Key.Value?
        where Key: StorageKey
    {
        guard let value = self.storage[ObjectIdentifier(Key.self)] as? Value<Key.Value> else {
            return nil
        }
        return value.value
    }

    /// Set or remove a value for a given key, optionally providing a shutdown closure for the value.
    ///
    /// If a key that has a shutdown closure is removed by this method, the closure **is** invoked.
    public mutating func set<Key>(
        _ key: Key.Type,
        to value: Key.Value?,
        onShutdown: (@Sendable (Key.Value) throws -> ())? = nil
    )
        where Key: StorageKey
    {
        let key = ObjectIdentifier(Key.self)
        if let value = value {
            self.storage[key] = Value(value: value, onShutdown: onShutdown)
        } else if let existing = self.storage[key] {
            self.storage[key] = nil
            existing.shutdown(logger: self.logger)
        }
    }

    /// For every key in the container having a shutdown closure, invoke the closure. Designed to
    /// be invoked during an explicit app shutdown process or in a reference type's `deinit`.
    public func shutdown() {
        self.storage.values.forEach {
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
public protocol StorageKey {
    /// The type of the stored value associated with this key type.
    associatedtype Value
}
