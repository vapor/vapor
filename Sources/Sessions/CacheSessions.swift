import Crypto
import Cache
import Node
import Foundation

public final class CacheSessions: SessionsProtocol {
    public let cache: Cache
    private let defaultExpiration: TimeInterval?

    public init(_ cache: Cache, defaultExpiration: TimeInterval? = nil) {
        self.cache = cache
        self.defaultExpiration = defaultExpiration
    }

    public func get(identifier: String) throws -> Session? {
        let data = try cache.get(identifier)
        guard data != .null else {
            return nil
        }

        return Session(identifier: identifier, data: data as! Node)
    }

    public func set(_ session: Session) throws {
        let expiration = defaultExpiration.map { Date(timeIntervalSinceNow: $0) }
        try cache.set(session.identifier, to: session.data as! CacheData, expiration: expiration)
    }

    public func destroy(identifier: String) throws{
        try cache.delete(identifier)
    }

    public func makeIdentifier() throws -> String {
        return try Crypto.Random.bytes(count: 16).base64Encoded.makeString()
    }
}
