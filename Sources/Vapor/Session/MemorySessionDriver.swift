import libc
import class Core.Lock

/**
    The `MemorySessionDriver` stores session data
    in a Swift `Dictionary`. This means all session
    data will be purged if the server is restarted.
*/
public class MemorySessions: Sessions {
    var sessions = [String: [String: String]]()
    private var sessionsLock = Lock()

    public var hash: Hash
    public init(hash: Hash) {
        self.hash = hash
    }

    /**
        Loads value for session id at given key
    */
    public func value(for key: String, identifier: String) -> String? {
        var value: String?
        sessionsLock.locked {
            value = sessions[identifier]?[key]
        }

        return value
    }

    /**
        Sets value for session id at given key
    */
    public func set(_ value: String?, for key: String, identifier: String) {
        sessionsLock.locked {
            if sessions[identifier] == nil {
                sessions[identifier] = [String: String]()
            }

            sessions[identifier]?[key] = value
        }
    }

    /**
        Returns true if the identifier is in use.
    */
    public func contains(identifier: String) -> Bool {
        return sessions[identifier] != nil
    }

    /**
        Create new unique session id
    */
    public func makeIdentifier() -> String {
        var identifier = time(nil).description
        identifier += "v@p0r"
        identifier += Int.random(min: 0, max: 9999).description
        identifier += "s3sS10n"
        identifier += Int.random(min: 0, max: 9999).description
        identifier += "k3y"
        identifier += Int.random(min: 0, max: 9999).description
        return hash.make(identifier)
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
