import Debugging

public enum ServiceError: Error, Debuggable {
    case multipleInstances(
        type: Any.Type
    )
    case disambiguationRequired(
        key: String,
        available: [String],
        type: Any.Type
    )
    case unknownService(
        available: [String],
        type: Any.Type
    )
    case incorrectType(
        type: Any.Type,
        desired: Any.Type
    )
    case noneAvailable(type: Any.Type)
    case unknown(Error)
}

extension ServiceError {
    public var reason: String {
        switch self {
        case .multipleInstances(let type):
            return "Multiple instances available for '\(type)'. Unable to disambiguate."
        case .noneAvailable(let type):
            return "No services are available for '\(type)'"
        case .disambiguationRequired(_, _, let type):
            return "Multiple services available for '\(type)', please disambiguate using config."
        case .unknownService(_, let type):
            return "No service was found while making a `\(type)`."
        case .incorrectType(let type, let desired):
            return "Service factory for `\(type)` did not create a service that conforms to `\(desired)`."
        case .unknown(let error):
            return "Unknown: \(error)"
        }
    }

    public var identifier: String {
        switch self {
        case .multipleInstances:
            return "multipleInstances"
        case .noneAvailable:
            return "none"
        case .disambiguationRequired:
            return "disambiguationRequired"
        case .unknownService:
            return "unknownService"
        case .incorrectType:
            return "incorrectType"
        case .unknown:
            return "unknown"
        }
    }

    public var possibleCauses: [String] {
        switch self {
        case .multipleInstances:
            return []
        case .noneAvailable:
            return [
                "A provider for this service was not properly configured."
            ]
        case .disambiguationRequired:
            return []
        case .unknownService:
            return []
        case .incorrectType:
            return []
        case .unknown:
            return []
        }
    }

    public var suggestedFixes: [String] {
        switch self {
        case .multipleInstances:
            return [
                "Register instances as service types instead, so they can be disambiguated using config."
            ]
        case .noneAvailable(let type):
            return [
                "Register a service that conforms to '\(type)' to the Container."
            ]
        case .disambiguationRequired(let key, let available, _):
            return [
                "Specify one of the available services in `app.json` at key `\(key)`.",
                "Use `try config.set(\"app\", \"\(key)\", to: \"<service>\")` with one of the available service names.",
                "Available services: \(available)"
            ]
        case .unknownService(let available, _):
            let string = available.joined(separator: ", ")
            return ["Try using one of the available types: \(string)"]
        case .incorrectType:
            return []
        case .unknown:
            return []
        }
    }
}
