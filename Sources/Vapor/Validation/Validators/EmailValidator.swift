extension Validator where T == String {
    /// Validates whether a `String` is a valid email address.
    ///
    ///     try validations.add(\.email, .email)
    ///
    public static var email: Validator<T> {
        return EmailValidator().validator()
    }
}

// MARK: Private

/// Validates whether a string is a valid email address.
private struct EmailValidator: ValidatorType {
    /// See `ValidatorType`.
    public var validatorReadable: String {
        return "a valid email address"
    }

    /// Creates a new `EmailValidator`.
    public init() {}

    /// See `Validator`.
    public func validate(_ s: String) -> ValidatorFailure? {
        guard
            let range = s.range(of: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}", options: [.regularExpression, .caseInsensitive]),
            range.lowerBound == s.startIndex && range.upperBound == s.endIndex
        else {
            return .init("is not a valid email address")
        }
        
        return nil
    }
}
