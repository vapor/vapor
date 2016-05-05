/**
    Represents the current environment the
    application is running in. This information
    can be used to conditionally show debug or testing information.
*/
public enum Environment: Equatable {
    case Production
    case Test
    case Development
    case Custom(String)

    init(id string: String) {
        switch string.lowercased() {
        case "production", "prod":
            self = .Production
        case "test":
            self = .Test
        case "development", "dev":
            self = .Development
        default:
            self = .Custom(string)
        }
    }
}

extension Environment: CustomStringConvertible {

    public var description: String {
        switch self {
        case Production: return "production"
        case Test: return "test"
        case Development: return "development"
        case Custom(let string): return string
        }
    }
}

public func == (lhs: Environment, rhs: Environment) -> Bool {
    return lhs.description == rhs.description
}
