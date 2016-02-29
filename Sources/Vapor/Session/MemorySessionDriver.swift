import Foundation

/**
 * The `MemorySessionDriver` stores session data
 * in a Swift `Dictionary`. This means all session
 * data will be purged if the server is restarted.
 */
public class MemorySessionDriver: SessionDriver {
    var sessions = [String: [String: String]]()

    public init() { }

    public func valueFor(key key: String, inSession session: Session) -> String? {
        guard let sessionIdentifier = session.sessionIdentifier else {
            Log.warning("Unable to read a value for '\(key)': The session has not been registered yet")
            return nil
        }

        return sessions[sessionIdentifier]?[key]
    }

    public func set(value: String?, forKey key: String, inSession session: Session) {
        guard let sessionIdentifier = session.sessionIdentifier else {
            Log.warning("Unable to store a value for '\(key)': The session has not been registered yet")
            return
        }

        if sessions[sessionIdentifier] == nil {
            sessions[sessionIdentifier] = [String: String]()
        }

        sessions[sessionIdentifier]?[key] = value
    }

    public func newSessionIdentifier() -> String {
        var identifier = String(NSDate().timeIntervalSinceNow)
        identifier += "v@p0r"
        identifier += String(Int.random(min: 0, max: 9999))
        identifier += "s3sS10n"
        identifier += String(Int.random(min: 0, max: 9999))
        identifier += "k3y"
        identifier += String(Int.random(min: 0, max: 9999))
        return Hash.make(identifier)
    }

    public func destroy(session: Session) {
        guard let sessionIdentifier = session.sessionIdentifier else {
            Log.warning("Unable to destroy the session: The session has not been registered yet")
            return
        }

        sessions[sessionIdentifier] = nil
    }
}
