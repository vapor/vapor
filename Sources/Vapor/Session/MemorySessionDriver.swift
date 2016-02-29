import Foundation

/**
 * The `MemorySessionDriver` stores session data
 * in a Swift `Dictionary`. This means all session
 * data will be purged if the server is restarted.
 */
public class MemorySessionDriver: SessionDriver {
    var sessions = [String: [String: String]]()

    public init() { }

    public func valueForKey(key: String, inSessionIdentifiedBy sessionIdentifier: String) -> String? {
        return sessions[sessionIdentifier]?[key]
    }

    public func setValue(value: String?, forKey key: String, inSessionIdentifiedBy sessionIdentifier: String) {
        if sessions[sessionIdentifier] == nil {
            sessions[sessionIdentifier] = [String: String]()
        }

        sessions[sessionIdentifier]![key] = value
    }

    public func createSessionIdentifier() -> String {
        var identifier = String(NSDate().timeIntervalSinceNow)
        identifier += "v@p0r"
        identifier += String(Int.random(min: 0, max: 9999))
        identifier += "s3sS10n"
        identifier += String(Int.random(min: 0, max: 9999))
        identifier += "k3y"
        identifier += String(Int.random(min: 0, max: 9999))
        return Hash.make(identifier)
    }

    public func destroySessionIdentifiedBy(sessionIdentifier: String) {
        sessions[sessionIdentifier] = nil
    }
}
