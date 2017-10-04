import Debugging

/// Errors that can be thrown while
/// attempting to attach, detach, or
/// check the relation on pivots.

// FIXME: convert to struct
public enum PivotError: Error {
    case idRequired(Model)
    case existRequired(Model)
    case unspecified(Error)
}

extension PivotError: Debuggable {
    public var identifier: String {
        switch self {
        case .idRequired:
            return "idRequired"
        case .existRequired:
            return "existRequired"
        case .unspecified:
            return "unspecified"
        }
    }

    public var reason: String {
        switch self {
        case .idRequired(let entity):
            return "Identifier required for \(entity)"
        case .existRequired(let entity):
            return "Entity must exist in the database. Try saving the entity first \(entity)"
        case .unspecified(let error):
            return "\(error)"
        }
    }

    public var possibleCauses: [String] {
        return [
            "model is being loaded manually without setting id and exists properly",
            "object wasn't fetched from database",
            "object doesn't exist in database yet"
        ]
    }

    public var suggestedFixes: [String] {
        return [
            "ensure object has been saved at least once",
            "if loading manually, ensure 'id' and 'exists' are properly set"
        ]
    }
}
