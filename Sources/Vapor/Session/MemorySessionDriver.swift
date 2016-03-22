import libc

/**
 * The `MemorySessionDriver` stores session data
 * in a Swift `Dictionary`. This means all session
 * data will be purged if the server is restarted.
 */
public class MemorySessionDriver: SessionDriver {
    var sessions = [String: [String: String]]()
    private var sessionsLock = Lock()

    public init() { }

    public func valueFor(key key: String, inSession session: Session) -> String? {
        var value: String?
        sessionsLock.locked {
            value = sessions[session.identifier]?[key]
        }

        return value
    }

    public func set(value: String?, forKey key: String, inSession session: Session) {
        sessionsLock.locked {
            if sessions[session.identifier] == nil {
                sessions[session.identifier] = [String: String]()
            }

            sessions[session.identifier]?[key] = value
        }
    }

    public func makeSessionIdentifier() -> String {
        var identifier = String(time(nil))
        identifier += "v@p0r"
        identifier += String(Int.random(min: 0, max: 9999))
        identifier += "s3sS10n"
        identifier += String(Int.random(min: 0, max: 9999))
        identifier += "k3y"
        identifier += String(Int.random(min: 0, max: 9999))
        return Hash.make(identifier)
    }

    public func destroy(session: Session) {
        sessionsLock.locked {
            sessions[session.identifier] = nil
        }
    }
}
