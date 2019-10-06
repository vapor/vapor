extension Validator where T: OptionalType, T.WrappedType: Codable {
    /// Validates that the data is `nil`. Combine with the not-operator `!` to validate that the data is not `nil`.
    public static var `nil`: Validator<T.WrappedType?> {
        NilValidator<T.WrappedType>().validator()
    }
}

public struct NilValidatorFailure: ValidatorFailure {}

/// Validates that the data is `nil`.
struct NilValidator<T: Decodable>: ValidatorType {

    /// See `Validator`.
    func validate(_ data: T?) -> NilValidatorFailure? {
        data == nil ? nil : .init()
    }
}
