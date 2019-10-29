extension Validator where T: Collection {

    /// Validates that the data is empty. You can also check a non empty state by combining with the `NotValidator`.
    public static var empty: Validator<T> {
        Empty().validator()
    }

    /// Validates whether the data is empty.
    public struct Empty: ValidatorType {
        public struct Result: ValidatorResult {
            /// See `CustomStringConvertible`.
            public let description = "empty"

            /// See `ValidatorResult`.
            public let failed: Bool
        }

        public init() {}

        /// See `ValidatorType`.
        public func validate(_ data: T) -> Result {
            .init(failed: !data.isEmpty)
        }
    }
}
