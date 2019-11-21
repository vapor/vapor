/// An error that is thrown when a validation results in at least 1 failed validation.
public struct ValidationsError: Error {

    /// A non-empty list of failed `PathedValidatorResult`s.
    public let failures: [PathedValidatorResult]

    init?(_ pathedValidatorResults: [PathedValidatorResult]) {
        self.failures = pathedValidatorResults.filter { $0.result.failed }

        if failures.isEmpty {
            return nil
        }
    }
}

extension ValidationsError: CustomStringConvertible {

    /// See `CustomStringConvertible`.
    public var description: String {
        failures.map { failure in
            "\(failure.path.dotPath): \(failure.result.description)"
        }.joined(separator: "\n")
    }
}
