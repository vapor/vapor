extension Validator where T: Decodable & Sendable {
    /// Validates whether a `String` matches a RegularExpression pattern
    public static func custom(
        _ validationDescription: String,
        validationClosure: @Sendable @escaping (T) -> Bool
    ) -> Validator<T> {
        return .init {
            let result = validationClosure($0)

            return ValidatorResults.Custom(
                isSuccess: result,
                validationDescription: validationDescription
            )
        }
    }
}

extension ValidatorResults {
    public struct Custom {
        public let isSuccess: Bool
        public let validationDescription: String
    }
}

extension ValidatorResults.Custom: ValidatorResult {
    public var isFailure: Bool {
        !self.isSuccess
    }

    public var successDescription: String? {
        "is successfully validated for custom validation '\(validationDescription)'."
    }

    public var failureDescription: String? {
        "is not successfully validated for custom validation '\(validationDescription)'."
    }
}
