extension Validator where T: Equatable {
    /// Validates whether an item is contained in the supplied array.
    public static func `in`(_ array: T...) -> Validator<T> {
        .in(array)
    }

    /// Validates whether an item is contained in the supplied sequence.
    public static func `in`<S: Sequence>(_ array: S) -> Validator<T> where S.Element == T {
        InValidator(array).validator()
    }
}

public struct InValidatorFailure: ValidatorFailure {}

/// Validates whether an item is contained in the supplied array.
struct InValidator<T: Decodable & Equatable>: ValidatorType {

    /// Array to check against.
    let contains: (T) -> Bool

    /// Creates a new `InValidator`.
    init<S: Sequence>(_ sequence: S) where S.Element == T {
        contains = sequence.contains
    }

    /// See `Validator`.
    func validate(_ item: T) -> InValidatorFailure? {
        contains(item) ? nil : .init()
    }
}
