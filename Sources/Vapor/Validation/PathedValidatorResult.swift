/// A `ValidatorResult` associated with a path
public struct PathedValidatorResult {

    /// The path to the value that was validated.
    public let path: [CodingKey]

    /// The result of the validation.
    public let result: ValidatorResult
}

extension PathedValidatorResult {


    /// Creates a new `PathedValidatorResult`.
    /// - Parameters:
    ///   - key: The `CodingKey` for the validated value.
    ///   - result: The result of the validation.
    public init(key: CodingKey, result: ValidatorResult) {
        path = [key]
        self.result = result
    }

    func prependingKey(_ key: CodingKey) -> PathedValidatorResult {
        .init(path: [key] + path, result: result)
    }
}
