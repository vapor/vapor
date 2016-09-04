/**
    Use the Session class to store sensitive
    information for individual users of your droplet
    such as API keys or login tokens.

    Access the current Droplet's Sessions using
    `drop.sessions`.
*/
public class Session {

    public var identifier: String?
    public var enabled: Bool

    private var sessions: Sessions
    public init(sessions: Sessions) {
        self.sessions = sessions
        enabled = false
    }

    init(identifier: String, sessions: Sessions) {
        self.sessions = sessions
        self.identifier = identifier
        enabled = true
    }

    public func destroy() {
        if let i = identifier {
            identifier = nil
            sessions.destroy(i)
        }
    }

    public subscript(key: String) -> String? {
        get {
            guard let i = identifier else {
                return nil
            }

            return sessions.value(for: key, identifier: i)
        }
        set {
            let i: String

            if let existingIdentifier = identifier {
                i = existingIdentifier
            } else {
                i = sessions.makeIdentifier()
                identifier = i
            }

            sessions.set(newValue, for: key, identifier: i)
        }
    }
}
