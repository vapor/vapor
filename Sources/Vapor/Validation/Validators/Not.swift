/// Inverts a `Validation`x`.
public prefix func ! <T>(validator: Validator<T>) -> Validator<T> {
    .init {
        ValidatorResults.Not(result: validator.validate($0))
    }
}

extension ValidatorResults {
    public struct Not: Sendable {
        public let result: ValidatorResult
    }
}

extension ValidatorResults.Not: ValidatorResult {
    public var isFailure: Bool {
        !self.result.isFailure
    }
    
    public var successDescription: String? {
        self.result.failureDescription
    }
    
    public var failureDescription: String? {
        return self.result.successDescription
    }
}
