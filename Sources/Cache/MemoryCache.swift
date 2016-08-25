import Node

public final class MemoryCache: CacheProtocol {
    private var _storage: [String: Node]

    public init() {
        _storage = [:]
    }

    public func get(_ key: String) throws -> Node? {
        return _storage[key]
    }

    public func set(_ key: String, _ value: Node) throws {
        _storage[key] = value
    }

    public func delete(_ key: String) throws {
        _storage.removeValue(forKey: key)
    }
}
