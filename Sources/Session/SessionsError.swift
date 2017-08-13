/// Errors that may arise while working
/// with sessions
public struct SessionsError: Error {
    enum Kind {
        case notConfigured
    }

    let kind: Kind
    public let reason: String

    init(kind: Kind, reason: String) {
        self.kind = kind
        self.reason = reason
    }

    public static func notConfigured() -> SessionsError {
        return .init(kind: .notConfigured, reason: "Sessions have not been properly configured")
    }
}

// MARK: Debuggable
import Debugging

extension SessionsError: Debuggable {
    public var identifier: String {
        switch kind {
        case .notConfigured:
            return "notConfigured"
        }
    }

    public var possibleCauses: [String] {
        switch kind {
        case .notConfigured:
            return ["The sessions middleware has not been added"]
        }
    }

    public var suggestedFixes: [String] {
        switch kind {
        case .notConfigured:
            return [
                "Add 'sessions' to the server middleware array in droplet.json",
                "Create a `SessionsMiddleware` and add it to the droplet"
            ]
        }
    }
}
