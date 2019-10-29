public struct PathedValidatorResult {
    public let path: [CodingKey]
    public let result: ValidatorResult
}

extension PathedValidatorResult {
    public init(key: CodingKey, result: ValidatorResult) {
        path = [key]
        self.result = result
    }

    func prependingKey(_ key: CodingKey) -> PathedValidatorResult {
        .init(path: [key] + path, result: result)
    }
}
