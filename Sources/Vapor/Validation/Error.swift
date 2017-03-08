public protocol ValidationError: Debuggable {}

// MARK: Error List

public struct ErrorList: ValidationError {
    public let errors: [Error]

    public init(_ errors: [Error]) {
        self.errors = errors
    }
}

extension ErrorList {
    public var identifier: String {
        return "errorList"
    }

    public var reason: String {
        let collected = errors.map { "\($0)" } .joined(separator: ",\n")
        return "Validation failed with the following errors:\n\(collected)"
    }

    public var possibleCauses: [String] { return [] }
    public var suggestedFixes: [String] { return [] }
}

// MARK: ValidatorError

public enum _ValidatorError: ValidationError {
    case failure(type: String, reason: String)
}

extension _ValidatorError {
    public var reason: String {
        switch self {
        case .failure(type: let type, reason: let reason):
            return "\(type) failed validation: \(reason)"
        }
    }

    public var identifier: String {
        switch self {
        case .failure(_):
            return "failure"
        }
    }

    public var possibleCauses: [String] { return [] }
    public var suggestedFixes: [String] { return [] }
}
