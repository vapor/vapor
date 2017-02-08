import Core
import Random
import Node

/**
    The `MemorySessionDriver` stores session data
    in a Swift `Dictionary`. This means all session
    data will be purged if the server is restarted.
*/
public class MemorySessions: SessionsProtocol {
    var sessions: [String: Node]
    private var sessionsLock = Lock()

    public init() {
        sessions = [:]
    }

    /**
        Loads value for session id at given key
    */
    public func get(for identifier: String) -> Node? {
        var value: Node?

        sessionsLock.locked {
            value = sessions[identifier]
        }

        return value
    }

    /**
        Sets value for session id at given key
    */
    public func set(_ value: Node?, for identifier: String) {
        sessionsLock.locked {
            sessions[identifier] = value
        }
    }

    /**
        Create new unique session id
    */
    public func makeIdentifier() -> String {
        return CryptoRandom.bytes(16).base64Encoded.string
    }

    /**
        Destroys session with associated identifier
    */
    public func destroy(_ identifier: String) {
        sessionsLock.locked {
            sessions[identifier] = nil
        }
    }
}
