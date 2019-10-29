extension Validator where T: OptionalType {

    /// Validates that the data is `nil`. Combine with the not-operator `!` to validate that the data is not `nil`.
    public static var `nil`: Validator<T> {
        Nil().validator()
    }

    /// Validates that the data is `nil`.
    public struct Nil: ValidatorType {
        public struct Result: ValidatorResult {

            /// See `CustomStringConvertible`.
            public let description = "nil"

            /// See `ValidatorResult`.
            public let failed: Bool
        }

        /// See `Validator`.
        public func validate(_ data: T) -> Result {
            .init(failed: data.wrapped != nil)
        }
    }
}
