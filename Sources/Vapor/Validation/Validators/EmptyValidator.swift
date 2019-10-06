extension Validator where T: Collection {
    /// Validates that the data is empty. You can also check a non empty state by combining with the `NotValidator`
    public static var empty: Validator<T> {
        EmptyValidator().validator()
    }
}

public struct EmptyValidatorFailure: ValidatorFailure {}

/// Validates whether the data is empty.
struct EmptyValidator<T: Collection & Decodable>: ValidatorType {

    /// See `ValidatorType`.
    func validate(_ data: T) -> EmptyValidatorFailure? {
        data.isEmpty ? nil : .init()
    }
}
