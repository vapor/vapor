public struct Validator<T: Decodable & Sendable>: Sendable {
    public let validate: @Sendable (_ data: T) -> any ValidatorResult
    @preconcurrency public init(validate: @Sendable @escaping (_ data: T) -> any ValidatorResult) {
        self.validate = validate
    }
}
