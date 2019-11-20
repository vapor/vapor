extension Validator where T: Collection {

    /// Validates that the data is empty. You can also check a non empty state by negating this validator: `!.empty`.
    public static var empty: Validator<T> {
        Empty(isInverted: false).validator()
    }

    /// `ValidatorResult` of a validator that validates whether the data is empty.
    public struct EmptyValidatorResult: ValidatorResult {

        /// The input is empty.
        public let isEmpty: Bool

        /// The `failed` state is inverted.
        public let isInverted: Bool

        /// See `CustomStringConvertible`.
        public var description: String { "is \(isEmpty ? "" : "not ")empty" }

        /// See `ValidatorResult`.
        public var failed: Bool { isEmpty == isInverted }
    }

    struct Empty: ValidatorType {
        let isInverted: Bool

        func inverted() -> Empty {
            .init(isInverted: !isInverted)
        }

        func validate(_ data: T) -> EmptyValidatorResult {
            .init(isEmpty: data.isEmpty, isInverted: isInverted)
        }
    }
}
