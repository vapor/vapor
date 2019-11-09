extension Validator where T: Collection {

    /// Validates that the data is empty. You can also check a non empty state by negating this validator: `!.empty`.
    public static var empty: Validator<T> {
        Empty().validator()
    }

    /// `ValidatorResult` of a validator that validates whether the data is empty.
    public struct EmptyValidatorResult: ValidatorResult {

        /// See `CustomStringConvertible`.
        public let description = "empty"

        /// See `ValidatorResult`.
        public let failed: Bool
    }

    struct Empty: ValidatorType {
        func validate(_ data: T) -> EmptyValidatorResult {
            .init(failed: !data.isEmpty)
        }
    }
}
