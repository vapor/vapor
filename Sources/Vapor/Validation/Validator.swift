public struct Validator<T: Decodable> {
    public let inverted: () -> Validator<T>
    public let validate: (_ data: T) -> ValidatorResult
}

public protocol ValidatorType {
    associatedtype Data: Decodable
    associatedtype Result: ValidatorResult
    func validate(_ data: Data) -> Result

    associatedtype Inverted: ValidatorType where Inverted.Data == Data
    func inverted() -> Inverted
}

extension ValidatorType {
    public func validator() -> Validator<Data> {
        return .init(inverted: inverted().validator, validate: validate)
    }
}

/// Inverts a `Validation`x`.
public prefix func ! <T: Decodable>(validator: Validator<T>) -> Validator<T> {
    validator.inverted()
}
