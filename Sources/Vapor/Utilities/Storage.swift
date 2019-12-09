public struct Storage {
    var storage: [ObjectIdentifier: Any]

    public init() {
        self.storage = [:]
    }

    public mutating func clear() {
        self.storage = [:]
    }

    public subscript<Key>(_ key: Key.Type) -> Key.Value?
        where Key: StorageKey
    {
        get {
            self.storage[ObjectIdentifier(Key.self)] as? Key.Value
        }
        set {
            self.storage[ObjectIdentifier(Key.self)] = newValue
        }
    }
}


public protocol StorageKey {
    associatedtype Value
}
