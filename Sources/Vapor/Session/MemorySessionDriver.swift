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
}
