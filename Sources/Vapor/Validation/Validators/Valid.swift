extension Validator {
    /// Validates nothing. Can be used as placeholder to validate successful decoding
    public static var valid: Validator<T> {
        .init { _ in
            ValidatorResults.Valid()
        }
    }
}

extension ValidatorResults {
    /// `ValidatorResult` of a validator that validates that the data is valid`.
    public struct Valid {
        /// As this validates nothing, this is always true.
        public let isValid: Bool = true
    }
}

extension ValidatorResults.Valid: ValidatorResult {
    public var isFailure: Bool {
        !self.isValid
    }

    public var successDescription: String? {
        "is valid"
    }

    public var failureDescription: String? {
        "is not valid"
    }
}
