public struct ValidatorFailure: CustomStringConvertible {
    public let reason: String
    public var description: String {
        return self.reason
    }
    public init(_ reason: String) {
        self.reason = reason
    }
}

public struct ValidationFailure {
    public let path: [CodingKey]
    public let failure: ValidatorFailure
    public var description: String {
        return "\(self.path.dotPath) \(self.failure.reason)"
    }
}

/// A collection of errors thrown by validatable models validations
public struct ValidationError: AbortError, CustomStringConvertible, LocalizedError {
    public var description: String {
        return self.reason
    }
    
    public var localizedDescription: String? {
        return self.description
    }
    
    public var errorDescription: String? {
        return self.description
    }
    
    public var status: HTTPStatus {
        return .badRequest
    }
    
    /// the errors thrown
    public var failures: [ValidationFailure]
    
    /// See ValidationError.reason
    public var reason: String {
        return self.failures.map { $0.description }.joined(separator: ", ")
    }
    
    /// creates a new validatable error
    public init(_ failures: [ValidationFailure]) {
        self.failures = failures
    }
}
