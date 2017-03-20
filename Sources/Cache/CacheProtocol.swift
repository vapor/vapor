import Node
import Foundation

public protocol CacheProtocol {
    func get(_ key: String) throws -> Node?
    func set(_ key: String, _ value: Node, expiration: Date?) throws
    func delete(_ key: String) throws
    var defaultExpiration: Date? { get }
}

extension CacheProtocol {
    public var defaultExpiration: Date? {
        return nil
    }
}

extension CacheProtocol {
    public func set(_ key: String, _ value: Node) throws {
        return try set(key, value, expiration: nil)
    }
    
    public func set(_ key: String, _ value: NodeRepresentable) throws {
        return try set(key, try value.makeNode(in: nil), expiration: defaultExpiration)
    }
    
    public func set(_ key: String, _ value: NodeRepresentable, expiration: Date?) throws {
        return try set(key, try value.makeNode(in: nil), expiration: expiration)
    }
}
