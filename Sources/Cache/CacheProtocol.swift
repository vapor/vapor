import Node
import Foundation

public protocol CacheProtocol {
    func get(_ key: String) throws -> Node?
    func set(_ key: String, _ value: Node, expiration: Date?) throws
    func delete(_ key: String) throws
    func makeDefaultExpiration() -> Date?
}

extension CacheProtocol {
    public func makeDefaultExpiration() -> Date? {
        return nil
    }
}

extension CacheProtocol {
    public func set(_ key: String, _ value: Node) throws {
        return try set(key, value, expiration: nil)
    }
    
    public func set(_ key: String, _ value: NodeRepresentable) throws {
        return try set(key, try value.makeNode(in: nil), expiration: makeDefaultExpiration())
    }
    
    public func set(_ key: String, _ value: NodeRepresentable, expiration: Date?) throws {
        return try set(key, try value.makeNode(in: nil), expiration: expiration)
    }
    
    public func set(_ key: String, _ value: NodeRepresentable, expireAfter: TimeInterval) throws {
        return try set(key, try value.makeNode(in: nil), expiration: Date(timeIntervalSinceNow: expireAfter))
    }
}
