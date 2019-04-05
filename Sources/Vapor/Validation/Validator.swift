public struct Validator<T>: CustomStringConvertible where T: Codable {
    public var description: String {
        return self.readable
    }
    public let readable: String
    public let validate: (_ data: T) -> ValidatorFailure?
}

/// Capable of validating validation data or throwing a validation error.
/// Use this protocol to organize code for creating `Validator`s.
///
///     let validator: Validator<T> = MyValidator().validator()
///
/// See `Validator` for more information.
public protocol ValidatorType {
    /// Data type to validate.
    associatedtype ValidationData: Codable

    /// Readable name explaining what this `Validator` does. Suitable for placing after `is` _and_ `is not`.
    ///
    ///     is alphanumeric
    ///     is not alphanumeric
    ///
    var validatorReadable: String { get }

    /// Validates the supplied `ValidationData`, throwing an error if it is not valid.
    ///
    /// - parameters:
    ///     - data: `ValidationData` to validate.
    /// - throws: `ValidationError` if the data is not valid, or another error if something fails.
    func validate(_ data: ValidationData) -> ValidatorFailure?
}

extension ValidatorType {
    public func validator() -> Validator<ValidationData> {
        return .init(readable: self.validatorReadable, validate: self.validate)
    }
}
