extension Validator where T: Equatable {
    /// Validates whether an item is contained in the supplied array.
    public static func `in`(_ array: T...) -> Validator<T> {
        .in(array)
    }

    /// Validates whether an item is contained in the supplied sequence.
    public static func `in`<S: Sequence>(_ array: S) -> Validator<T> where S.Element == T {
        In(array).validator()
    }
}

extension Validator {
    /// Validates whether an item is contained in the supplied array.
    public struct In<T: Decodable & Equatable>: ValidatorType {
        public struct Failure: ValidatorFailure {}

        /// Array to check against.
        let contains: (T) -> Bool

        /// Creates a new `InValidator`.
        public init<S: Sequence>(_ sequence: S) where S.Element == T {
            contains = sequence.contains
        }

        /// See `Validator`.
        public func validate(_ item: T) -> Failure? {
            contains(item) ? nil : .init()
        }
    }
}
