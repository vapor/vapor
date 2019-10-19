extension Validator where T: Collection {

    /// Validates that the data is empty. You can also check a non empty state by combining with the `NotValidator`.
    public static var empty: Validator<T> {
        Empty().validator()
    }

    /// Validates whether the data is empty.
    public struct Empty: ValidatorType {
        public struct Failure: ValidatorFailure {}

        public init() {}

        /// See `ValidatorType`.
        public func validate(_ data: T) -> Failure? {
            data.isEmpty ? nil : .init()
        }
    }
}

extension Validator.Empty.Failure: CustomStringConvertible {

    /// See `CustomStringConvertible`.
    public var description: String {
        "is not empty"
    }
}
