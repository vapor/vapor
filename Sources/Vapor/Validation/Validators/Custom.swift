extension Validator where T: Decodable & Sendable {
    /// Validates whether a `String` matches a RegularExpression pattern
    public static func custom(
        validationDescription: String,
        successMessage: String? = nil,
        failureMessage: String? = nil,
        validationClosure: @Sendable @escaping (T) -> Bool
    ) -> Validator<T> {
        return .init {
            let result = validationClosure($0)
            
            return ValidatorResults.Custom(
                isValidResult: result,
                validationDescription: validationDescription,
                successMessage: successMessage ?? "is successfully validated for custom validation '\(validationDescription)'.",
                failureMessage: failureMessage ?? "is unsuccessfully validated for custom validation '\(validationDescription)'."
            )
        }
    }
}

extension ValidatorResults {
    /// `ValidatorResult` of a validator that validates whether a `String`matches a RegularExpression pattern
    public struct Custom{
        public let isValidResult: Bool
        public let validationDescription: String
        public let successMessage: String
        public let failureMessage: String
    }
}

extension ValidatorResults.Custom: ValidatorResult {
    public var isFailure: Bool {
        /// The input is valid for the pattern
        !self.isValidResult
    }
    public var successDescription: String? {
        self.successMessage
    }
    public var failureDescription: String? {
        self.failureMessage
    }
}
