/**
    Represents the current environment the
    droplet is running in. This information
    can be used to conditionally show debug or testing information.
*/
public enum Environment: Equatable {
    case production
    case test
    case development
    case custom(String)

    public init(id string: String) {
        switch string.lowercased() {
        case "production", "prod":
            self = .production
        case "test":
            self = .test
        case "development", "dev":
            self = .development
        default:
            self = .custom(string)
        }
    }
}

extension Environment: CustomStringConvertible {

    public var description: String {
        switch self {
        case .production: return "production"
        case .test: return "test"
        case .development: return "development"
        case .custom(let string): return string
        }
    }

}

public func == (lhs: Environment, rhs: Environment) -> Bool {
    return lhs.description == rhs.description
}

extension CommandLine {
    public static var environment: Environment? {
        return arguments.value(for: "env").flatMap(Environment.init)
    }
}

extension Sequence where Iterator.Element == String {
    func value(for string: String) -> String? {
        for item in self {
            let search = "--\(string)="
            if item.hasPrefix(search) {
                return item.components(separatedBy: search).joined(separator: "")
            }
        }

        return nil
    }
}
