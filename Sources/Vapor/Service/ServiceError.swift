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
        name: String,
        available: [String],
        type: Any.Type
    )
    case duplicateServiceName(
        name: String,
        type: Any.Type
    )
    case incorrectType(
        name: String,
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
        case .unknownService(let name, _, let type):
            return "No service named \"\(name)\" was found while making a '\(type)'."
        case .duplicateServiceName(let name, let type):
            return "Duplicate service names were resolved for \"\(name)\" while making a '\(type)'"
        case .incorrectType(let name, let type, let desired):
            return "Service factory for \(type) named \(name) did not create a service that conforms to \(desired)."
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
        case .duplicateServiceName:
            return "duplicate"
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
        case .duplicateServiceName:
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
                "Register a service that conforms to '\(type)' to the Droplet."
            ]
        case .disambiguationRequired(let key, let available, _):
            return [
                "Specify one of the available services in `droplet.json` at key `\(key)`.",
                "Use `try config.set(\"droplet.\(key)\", <service>)` with one of the available service names.",
                "Available services: \(available)"
            ]
        case .unknownService(_, let available, _):
            let string = available.joined(separator: ", ")
            return ["Try using one of the available types: \(string)"]
        case .duplicateServiceName:
            return []
        case .incorrectType:
            return []
        case .unknown:
            return []
        }
    }
}
