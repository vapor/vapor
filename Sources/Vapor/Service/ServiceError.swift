public enum ServiceError: Error, Debuggable {
    case unknown(Error)
}

extension ServiceError {
    public var reason: String {
        switch self {
        case .unknown(let error):
            return "Unknown: \(error)"
        }
    }

    public var identifier: String {
        switch self {
        case .unknown:
            return "unknown"
        }
    }

    public var possibleCauses: [String] {
        switch self {
        case .unknown:
            return []
        }
    }

    public var suggestedFixes: [String] {
        switch self {
        case .unknown:
            return []
        }
    }
}
