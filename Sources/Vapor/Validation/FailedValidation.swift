struct FailedValidation {
    let path: [CodingKey]
    let failure: ValidatorFailure
}

extension FailedValidation {
    init(key: CodingKey, failure: ValidatorFailure) {
        path = [key]
        self.failure = failure
    }
    func prependingKey(_ key: CodingKey) -> FailedValidation {
        return FailedValidation(path: [key] + self.path, failure: failure)
    }
}
