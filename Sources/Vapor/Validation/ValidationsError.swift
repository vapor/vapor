public struct ValidationsError: Error {
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
            "\(failure.path.dotPath): is \(failure.result.failed ? "not " : "")\(failure.result.description)"
                .replacingOccurrences(of: "not not ", with: "")
        }.joined(separator: "\n")
    }
}
