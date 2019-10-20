public struct FailedValidation {
    public let path: [CodingKey]
    public let failure: ValidatorFailure
}

extension FailedValidation {
    public init(key: CodingKey, failure: ValidatorFailure) {
        path = [key]
        self.failure = failure
    }

    func prependingKey(_ key: CodingKey) -> FailedValidation {
        return FailedValidation(path: [key] + self.path, failure: failure)
    }
}
