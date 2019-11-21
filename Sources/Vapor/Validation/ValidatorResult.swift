/// Represents the result of a `Validator`'s validation.
public protocol ValidatorResult: CustomStringConvertible {

    /// The validation has failed.
    var failed: Bool { get }
}
