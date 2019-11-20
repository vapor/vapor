extension Validator where T: Equatable {

    /// Validates whether an item is contained in the supplied array.
    public static func `in`(_ array: T...) -> Validator<T> {
        .in(array)
    }

    /// Validates whether an item is contained in the supplied sequence.
    public static func `in`<S: Sequence>(_ sequence: S) -> Validator<T> where S.Element == T {
        In(sequence).validator()
    }

    /// `ValidatorResult` of a validator that validates whether an item is contained in the supplied sequence.
    public struct InValidatorResult: ValidatorResult {

        /// The item is contained in the supplied sequence.
        public let contained: Bool

        /// Descriptions of the elements of the supplied sequence.
        public let elementDescriptions: [String]

        /// The `failed` state is inverted.
        public let isInverted: Bool

        /// See `CustomStringConvertible`.
        public var description: String {
            "\(contained ? "" : "not ")contained in \(elementDescriptions.joined(separator: ", ")))"
        }

        /// See `ValidatorResult`.
        public var failed: Bool { contained == isInverted }
    }

    struct In: ValidatorType {
        let contains: (T) -> Bool
        let elementDescriptions: () -> [String]
        let isInverted: Bool

        func inverted() -> In {
            .init(contains: contains, elementDescriptions: elementDescriptions, isInverted: !isInverted)
        }

        func validate(_ item: T) -> InValidatorResult {
            .init(contained: contains(item), elementDescriptions: elementDescriptions(), isInverted: isInverted)
        }
    }
}

extension Validator.In {
    init<S: Sequence>(_ sequence: S) where S.Element == T {
        contains = sequence.contains
        elementDescriptions = { sequence.map(String.init(describing:)) }
        isInverted = false
    }
}
