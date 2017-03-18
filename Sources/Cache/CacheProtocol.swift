import Node
import Foundation

public protocol CacheProtocol {
    func get(_ key: String) throws -> Node?
    func set(_ key: String, _ value: Node, expiration: Date?) throws
    func delete(_ key: String) throws
}

extension CacheProtocol {
    public func set(_ key: String, _ value: Node) throws {
        try set(key, value, expiration: nil)
    }

    public func set(_ key: String, _ value: NodeRepresentable, expiration: Date? = nil) throws {
        return try set(key, try value.makeNode(), expiration: expiration)
    }
}
