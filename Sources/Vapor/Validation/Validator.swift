public struct Validator<T: Decodable> {
    public let validate: (_ data: T) -> ValidatorResult
    public init(validate: @escaping (_ data: T) -> ValidatorResult) {
        self.validate = validate
    }
}
