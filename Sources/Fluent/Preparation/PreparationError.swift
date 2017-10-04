import Debugging

// FIXME: make struct

public enum PreparationError: Error {
    case neverPrepared(Preparation.Type)
    case unspecified(Error)
}

extension PreparationError: Debuggable {
    public var identifier: String {
        switch self {
        case .neverPrepared:
            return "neverPrepared"
        case .unspecified(_):
            return "unspecified"
        }
    }

    public var reason: String {
        switch self {
        case .neverPrepared(let type):
            return "Cannot revert \(type) because it has never prepared."
        case .unspecified(let error):
            return "unspecified \(error)"
        }
    }

    public var possibleCauses: [String] {
        return []
    }

    public var suggestedFixes: [String] {
        return []
    }
}
