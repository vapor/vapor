import Core
import Crypto
import Node
import Foundation

/// The `MemorySessionDriver` stores session data
/// in a Swift `Dictionary`. This means all session
/// data will be purged if the server is restarted.
public final class MemorySessions: SessionsProtocol {
    var sessions: [String: (
        identifier: String,
        data: Node
    )]
    
    private var sessionsLock = NSLock()

    public init() {
        sessions = [:]
    }

    /// Loads value for session id at given key
    public func get(identifier: String) -> Session? {
        var session: Session?
        
        sessionsLock.locked {
            if let existing = sessions[identifier] {
                session = Session(
                    identifier: existing.identifier,
                    data: existing.data
                )
            } else {
                session = nil
            }
        }
        
        return session
    }

    /// Sets value for session id at given key
    public func set(_ session: Session) {
        sessionsLock.locked {
            sessions[session.identifier] = (
                session.identifier,
                session.data
            )
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
