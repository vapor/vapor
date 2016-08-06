import Redbird
import Cache
import Node

public final class RedisCache: CacheProtocol {
    public let redbird: Redbird

    public init(redbird: Redbird) {
        self.redbird = redbird
    }

    public enum Error: Swift.Error {
        case incompatibleValue
    }

	public func get(_ key: String) throws -> Node? {
        guard let result = try redbird.command("GET", params: [key]).toMaybeString() else {
            return nil
        }

        return Node.string(result)
	}

	public func set(_ key: String, _ value: Node) throws {
        guard let string = value.string else {
            throw Error.incompatibleValue
        }

        try redbird.command("SET", params: [key, string])
	}

    public func delete(_ key: String) throws {
        try redbird.command("DEL", params: [key])
    }
}
