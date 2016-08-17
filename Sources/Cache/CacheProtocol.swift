import Node

public protocol CacheProtocol {
    func get(_ key: String) throws -> Node?
    func set(_ key: String, _ value: Node) throws
    func delete(_ key: String) throws
}

extension CacheProtocol {
    public func set(_ key: String, _ value: NodeRepresentable) throws {
        return try set(key, try value.makeNode())
    }
}
