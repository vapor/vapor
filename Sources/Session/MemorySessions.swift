import Core
import Crypto
import Foundation
import Service

/// The `MemorySessionDriver` stores session data
/// in a Swift `Dictionary`. This means all session
/// data will be purged if the server is restarted.
public final class MemorySessions: Sessions {
    // Private storage
    private var _storage: [String: (
        identifier: String,
        data: SessionData
    )]

    /// Used to synchronize access to the session data.
    private var lock = NSLock()

    public init() {
        _storage = [:]
    }

    /// Loads value for session id at given key
    public func get(identifier: String) -> Session? {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard let existing = _storage[identifier] else {
            return nil
        }

        return Session(
            identifier: existing.identifier,
            data: existing.data
        )
    }

    /// Sets value for session id at given key
    public func set(_ session: Session) {
        lock.lock()
        defer {
            lock.unlock()
        }

        _storage[session.identifier] = (
            session.identifier,
            session.data
        )
    }
    
    /// Destroys session with associated identifier
    public func destroy(identifier: String) throws {
        lock.lock()
        defer {
            lock.unlock()
        }

        _storage[identifier] = nil
    }

    /// Create new unique session id
    public func makeIdentifier() throws -> String {
        return try Crypto.Random.bytes(count: 16).base64Encoded.makeString()
    }
}

// MARK: Service

extension MemorySessions: ServiceType {
    /// See Service.name
    public static var serviceName: String {
        return "memory"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [Sessions.self]
    }

    /// See Service.make
    public static func makeService(for container: Container) throws -> MemorySessions? {
        return .init()
    }
}
