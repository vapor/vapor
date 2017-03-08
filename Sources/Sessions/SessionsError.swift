/// Errors that may arise while working
/// with sessions
public enum SessionsError: Error {
    case notConfigured
    case unspecified(Error)
}

// MARK: Debuggable
import Debugging

extension SessionsError: Debuggable {
    public var reason: String {
        switch self {
        case .notConfigured:
            return "Sessions have not been properly configured"
        case .unspecified(let error):
            return "Unknown: \(error)"
        }
    }

    public var identifier: String {
        switch self {
        case .notConfigured:
            return "notConfigured"
        case .unspecified:
            return "unspecified"
        }
    }

    public var possibleCauses: [String] {
        switch self {
        case .notConfigured:
            return ["The sessions middleware has not been added"]
        case .unspecified(let error):
            return (error as? Debuggable)?.possibleCauses ?? []
        }
    }

    public var suggestedFixes: [String] {
        switch self {
        case .notConfigured:
            return [
                "Add 'sessions' to the server middleware array in droplet.json",
                "Create a `SessionsMiddleware` and add it to the droplet"
            ]
        case .unspecified(let error):
            return (error as? Debuggable)?.suggestedFixes ?? []
        }
    }
}
