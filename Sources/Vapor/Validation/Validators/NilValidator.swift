extension Validator where T: OptionalType, T.WrappedType: Codable {
    /// Validates that the data is `nil`. Combine with the not-operator `!` to validate that the data is not `nil`.
    ///
    ///     try validations.add(\.email, .email && !.nil)
    ///
    public static var `nil`: Validator<T.WrappedType?> {
        return NilValidator(T.WrappedType.self).validator()
    }
}

/// Validates that the data is `nil`.
fileprivate struct NilValidator<T>: ValidatorType where T: Codable {
    typealias ValidationData = T?

    /// See `Validator`.
    var validatorReadable: String {
        return "nil"
    }

    /// Creates a new `NilValidator`.
    init(_ type: T.Type) {}

    /// See `Validator`.
    func validate(_ data: T?) -> ValidatorFailure? {
        if data != nil {
            return .init("is not nil")
        } else {
            return nil
        }
    }
}
