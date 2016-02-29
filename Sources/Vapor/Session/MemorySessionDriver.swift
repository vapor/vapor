import Foundation

/**
 * The `MemorySessionDriver` stores session data
 * in a Swift `Dictionary`. This means all session
 * data will be purged if the server is restarted.
 */
public class MemorySessionDriver: SessionDriver {
	var sessions = [String: Session]()

    public init() { }

    public subscript(sessionIdentifier: String) -> Session {
        guard let session = sessions[sessionIdentifier] else {
            let newSession = MemorySession()
            sessions[sessionIdentifier] = newSession
            return newSession
        }

        return session
    }
}

public final class MemorySession: Session {
    var data = [String: String]()

    private init() { }

    public subscript(key: String) -> String? {
        get {
            return data[key]
        }

        set(newValue) {
            data[key] = newValue
        }
    }
}
