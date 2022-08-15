#if canImport(_Concurrency)

/// A container providing arbitrary storage for extensions of an existing type, designed to obviate
/// the problem of being unable to add stored properties to a type in an extension. Each stored item
/// is keyed by a type conforming to ``StorageKey`` protocol.
public actor AsyncStorage {
    /// The internal storage area.
    var storage: [ObjectIdentifier: AnyAsyncStorageValue]

    /// A container for a stored value and an associated optional `deinit`-like closure.
    struct Value<T>: AnyAsyncStorageValue {
        var value: T
        var onShutdown: ((T) async throws -> ())?
        func shutdown(logger: Logger) async {
            do {
                try await self.onShutdown?(self.value)
            } catch {
                logger.warning("Could not shutdown \(T.self): \(error)")
            }
        }
    }
    
    /// The logger provided to shutdown closures.
    let logger: Logger

    /// Create a new ``Storage`` container using the given logger.
    public init(logger: Logger = .init(label: "codes.vapor.storage")) {
        self.storage = [:]
        self.logger = logger
    }

    /// Delete all values from the container. Does _not_ invoke shutdown closures.
    public func clear() {
        self.storage = [:]
    }

//    /// Read/write access to values via keyed subscript.
//    public subscript<Key>(_ key: Key.Type) async -> Key.Value?
//        where Key: StorageKey
//    {
//        get {
//            self.get(Key.self)
//        }
//        set {
//            await self.set(Key.self, to: newValue)
//        }
//    }
//
//    /// Read access to a value via keyed subscript, adding the provided default
//    /// value to the storage if the key does not already exist. Similar to
//    /// ``Swift/Dictionary/subscript(key:default:)``. The `defaultValue` autoclosure
//    /// is evaluated only when the key does not already exist in the container.
//    public subscript<Key>(_ key: Key.Type, default defaultValue: @autoclosure () -> Key.Value) -> Key.Value
//        where Key: StorageKey
//    {
//        get {
//            if let existing = self[key] { return existing }
//            let new = defaultValue()
//            await self.set(Key.self, to: new)
//            return new
//        }
//    }

    /// Test whether the given key exists in the container.
    public func contains<Key>(_ key: Key.Type) -> Bool {
        self.storage.keys.contains(ObjectIdentifier(Key.self))
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
    public func set<Key>(
        _ key: Key.Type,
        to value: Key.Value?,
        onShutdown: ((Key.Value) async throws -> ())? = nil
    ) async
        where Key: StorageKey
    {
        let key = ObjectIdentifier(Key.self)
        if let value = value {
            self.storage[key] = Value(value: value, onShutdown: onShutdown)
        } else if let existing = self.storage[key] {
            self.storage[key] = nil
            await existing.shutdown(logger: self.logger)
        }
    }

    /// For every key in the container having a shutdown closure, invoke the closure. Designed to
    /// be invoked during an explicit app shutdown process or in a reference type's `deinit`.
    public func shutdown() async {
        for storageValue in self.storage.values {
            await storageValue.shutdown(logger: self.logger)
        }
    }
}

/// ``Storage`` uses this protocol internally to generically invoke shutdown closures for arbitrarily-
/// typed key values.
protocol AnyAsyncStorageValue {
    func shutdown(logger: Logger) async
}

#endif
