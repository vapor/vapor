public struct Validator<T: Decodable> {
    public let validate: (_ data: T) -> ValidatorFailure?
}

public protocol ValidatorType {
    associatedtype Data: Decodable
    associatedtype Failure: ValidatorFailure
    func validate(_ data: Data) -> Failure?
    func validator() -> Validator<Data>
}

extension ValidatorType {
    public func validator() -> Validator<Data> {
        .init(validate: validate)
    }
}
