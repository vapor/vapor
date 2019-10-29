public struct Validator<T: Decodable> {
    public let validate: (_ data: T) -> ValidatorResult
}

public protocol ValidatorType {
    associatedtype Data: Decodable
    associatedtype Result: ValidatorResult
    func validate(_ data: Data) -> Result
    func validator() -> Validator<Data>
}

extension ValidatorType {
    public func validator() -> Validator<Data> {
        .init(validate: validate)
    }
}
