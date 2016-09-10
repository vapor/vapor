import Node

/**
    Use the Session class to store sensitive
    information for individual users of your droplet
    such as API keys or login tokens.

    Access the current Droplet's Sessions using
    `drop.sessions`.
*/
public final class Session {
    public var identifier: String?

    private var sessions: SessionsProtocol

    init(sessions: SessionsProtocol) {
        self.sessions = sessions
    }

    public func destroy() throws {
        if let i = identifier {
            identifier = nil
            try sessions.destroy(i)
        }
    }

    public var data: Node {
        get {
            let i: String

            if let existingIdentifier = identifier {
                i = existingIdentifier
            } else {
                i = sessions.makeIdentifier()
                identifier = i
            }

            do {
                if let data = try sessions.get(for: i) {
                    return data
                } else {
                    let new = Node([:])
                    try sessions.set(new, for: i)
                    return new
                }
            } catch {
                print("[Sessions] Error getting data: \(error)")
                return nil
            }
        }
        set {
            let i: String

            if let existingIdentifier = identifier {
                i = existingIdentifier
            } else {
                i = sessions.makeIdentifier()
                identifier = i
            }

            do {
                try sessions.set(newValue, for: i)
            } catch {
                print("[Sessions] Error setting data: \(error)")
            }
        }
    }
}
