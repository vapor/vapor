public struct Validator<T: Decodable> {
    public let validate: (_ data: T) -> ValidatorResult
}
