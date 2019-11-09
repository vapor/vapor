import Foundation

extension Validator where T: Equatable {

    /// Validates whether an item is contained in the supplied array.
    public static func `in`(_ array: T...) -> Validator<T> {
        .in(array)
    }

    /// Validates whether an item is contained in the supplied sequence.
    public static func `in`<S: Sequence>(_ array: S) -> Validator<T> where S.Element == T {
        In(array).validator()
    }

    /// Validates whether an item is contained in the supplied array.
    public struct In: ValidatorType {
        public struct Result: ValidatorResult {
            let elementDescriptions: () -> [String]

            /// See `CustomStringConvertible`.
            public var description: String {
                "contained in \(elementDescriptions().joined(separator: ", ")))"
            }

            /// See `ValidatorResult`.
            public let failed: Bool
        }

        /// Closure to determine whether an element is in the sequence.
        let contains: (T) -> Bool
        let elementDescriptions: () -> [String]

        /// Creates a new `InValidator`.
        public init<S: Sequence>(_ sequence: S) where S.Element == T {
            contains = sequence.contains
            elementDescriptions = { sequence.map(String.init(describing:)) }
        }

        /// See `Validator`.
        public func validate(_ item: T) -> Result {
            .init(elementDescriptions: elementDescriptions, failed: !contains(item))
        }
    }
}
