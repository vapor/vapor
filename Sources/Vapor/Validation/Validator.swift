public struct Validator<T: Decodable> {
    public let validate: (_ data: T) -> ValidatorResult
}

public protocol ValidatorType {
    associatedtype Data: Decodable
    func validate(_ data: Data) -> ValidatorResult
}

extension ValidatorType {
    public func validator() -> Validator<Data> {
        return .init(validate: self.validate)
    }
}
