extension Validator where T: OptionalType {

    /// Validates that the data is `nil`. Combine with the not-operator `!` to validate that the data is not `nil`.
    public static var `nil`: Validator<T> {
        Nil().validator()
    }

    /// `ValidatorResult` of a validator that validates that the data is `nil`.
    public struct NilValidatorResult: ValidatorResult {

        /// See `CustomStringConvertible`.
        public let description = "nil"

        /// See `ValidatorResult`.
        public let failed: Bool
    }

    struct Nil: ValidatorType {
        func validate(_ data: T) -> NilValidatorResult {
            .init(failed: data.wrapped != nil)
        }
    }
}
