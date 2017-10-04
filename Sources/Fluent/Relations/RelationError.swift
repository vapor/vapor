import Debugging

/// Errors thrown while interacting
/// with relations on entities.
/// Ex: Children, Parent, Siblings
public enum RelationError {
    case idRequired(Model)
    case unspecified(Error)
}

extension RelationError: Debuggable {
    public var identifier: String {
        switch self {
        case .idRequired:
            return "idRequired"
        case .unspecified:
            return "unspecified"
        }
    }

    public var reason: String {
        switch self {
        case .idRequired(let entity):
            return "Required identifier is missing for entity \(entity)"
        case .unspecified(let error):
            return "An unspecified error was received \(error)"
        }
    }

    public var possibleCauses: [String] {
        switch self {
        case .idRequired:
            return [
                "id was overwritten to `nil` unexpectedly",
                "object wasn't properly fetched from database before using",
                "database is corrupt or has unexpected values",
                "manually loaded object without setting id"
            ]
        case .unspecified:
            return [
                "we received an error that was unspecified in this version"
            ]
        }
    }

    public var suggestedFixes: [String] {
        switch self {
        case .idRequired:
            return [
                "ensure the object is loading properly on database fetch",
                "verify database tables are as expected",
                "if loading object manually, make sure that id is appropriately set",
            ]
        case .unspecified:
            return [
                "upgrading library can occasional resolve unspecified issues",
                "look for information around the encapsulated error"
            ]
        }
    }
}
