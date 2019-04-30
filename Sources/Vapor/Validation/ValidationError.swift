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

public struct ValidationError: AbortError, CustomStringConvertible, LocalizedError {
    public let failures: [ValidationFailure]
    
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
    
    public var reason: String {
        return self.failures.map { $0.description }.joined(separator: ", ")
    }
    
    public init(_ failures: [ValidationFailure]) {
        self.failures = failures
    }
}
