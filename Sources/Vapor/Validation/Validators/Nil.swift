extension Validator where T: OptionalType {

    /// Validates that the data is `nil`. Combine with the not-operator `!` to validate that the data is not `nil`.
    public static var `nil`: Validator<T> {
        Nil(isInverted: false).validator()
    }

    /// `ValidatorResult` of a validator that validates that the data is `nil`.
    public struct NilValidatorResult: ValidatorResult {

        /// The `failed` state is inverted.
        public let isInverted: Bool

        /// Input is `nil`.
        public let isNil: Bool

        /// See `CustomStringConvertible`.
        public var description: String { "\(isNil ? "" : "not ")nil" }

        /// See `ValidatorResult`.
        public var failed: Bool { isNil == isInverted }
    }

    struct Nil: ValidatorType {
        let isInverted: Bool

        func inverted() -> Nil {
            .init(isInverted: !isInverted)
        }

        func validate(_ data: T) -> NilValidatorResult {
            .init(isInverted: isInverted, isNil: data.wrapped == nil)
        }
    }
}
