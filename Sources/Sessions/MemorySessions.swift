import Core
import Crypto
import Node
import Foundation

/// The `MemorySessionDriver` stores session data
/// in a Swift `Dictionary`. This means all session
/// data will be purged if the server is restarted.
public class MemorySessions: SessionsProtocol {
    var sessions: [String: Session]
    private var sessionsLock = NSLock()

    public init() {
        sessions = [:]
    }

    /// Loads value for session id at given key
    public func get(identifier: String) -> Session? {
        var session: Session?

        sessionsLock.locked {
            session = sessions[identifier]
        }

        return session
    }

    /// Sets value for session id at given key
    public func set(_ session: Session) {
        sessionsLock.locked {
            sessions[session.identifier] = session
        }
    }
    
    /// Destroys session with associated identifier
    public func destroy(identifier: String) throws {
        sessionsLock.locked {
            sessions[identifier] = nil
        }
    }

    /// Create new unique session id
    public func makeIdentifier() throws -> String {
        return try Crypto.Random.bytes(count: 16).base64Encoded.makeString()
    }
}
