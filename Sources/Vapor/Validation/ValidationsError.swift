public struct ValidationsError: Error {
    public let failedValidations: [FailedValidation]

    init?(_ failedValidations: [FailedValidation]) {
        guard !failedValidations.isEmpty else {
            return nil
        }
        self.failedValidations = failedValidations
    }
}

extension ValidationsError: CustomStringConvertible {

    /// See `CustomStringConvertible`.
    public var description: String {
        failedValidations.map { failedValidation in
            "\(failedValidation.path.dotPath): \(String(describing: failedValidation))"
        }.joined(separator: "\n")
    }
}
