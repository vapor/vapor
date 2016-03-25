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

    static func fromString(string: String) -> Environment {
        #if swift(>=3.0)
            let string = string.lowercased()
        #else
            let string = string.lowercaseString
        #endif

        switch string {
        case "production", "prod": return .Production
        case "test": return .Test
        case "development", "dev": return .Development
        default: return .Custom(string)
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

public func ==(lhs: Environment, rhs: Environment) -> Bool {
    return lhs.description == rhs.description
}
