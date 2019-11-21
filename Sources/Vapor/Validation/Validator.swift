/// A discrete `Validator`. Usually created by calling `ValidatorType.validator()`.
///
/// All validation operators (`&&`, `||`, `!`, etc.) work on `Validator`s.
///
///     Validation("firstName", as: String.self, is: .count(5...) && .alphanumeric)
///
/// Adding static properties to this type will enable leading-dot syntax when composing validators.
///
///     extension Validator {
///         static var myValidation: Validator<T> { MyValidator().validator() }
///     }
///
public struct Validator<T: Decodable> {

    /// Create an inverted version of this validator. Used by the `!` operator.
    public let inverted: () -> Validator<T>

    /// A closure that validates some data and produces a `ValidatorResult`.
    public let validate: (_ data: T) -> ValidatorResult
}

/// Capable of validating validation data.
/// Use this protocol to organize code for creating `Validator`s.
///
///     let validator: Validator<T> = MyValidator().validator()
///
/// See `Validator` for more information.
public protocol ValidatorType {

    /// Data type to validate.
    associatedtype Data: Decodable

    /// Data type to return when validating.
    associatedtype Result: ValidatorResult

    /// Validates the supplied `ValidationData`. The `failed` property of the `Result` will be true iff the data is valid.
    ///
    /// - Parameter data: the `Data`
    func validate(_ data: Data) -> Result

    /// Validator type of the inverted version of this validator.
    associatedtype Inverted: ValidatorType where Inverted.Data == Data

    /// Returns a `ValidatorType` that will fail validation if this one does not and vice versa.
    func inverted() -> Inverted
}

extension ValidatorType {

    /// Create a `Validator` for this `ValidatorType`.
    public func validator() -> Validator<Data> {
        .init(inverted: inverted().validator, validate: validate)
    }
}

/// Inverts a `Validation`.
public prefix func ! <T: Decodable>(validator: Validator<T>) -> Validator<T> {
    validator.inverted()
}
