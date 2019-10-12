public struct ValidationsError: Error, CustomStringConvertible {
    let failedValidations: [FailedValidation]

    init?(_ failedValidations: [FailedValidation]) {
        guard !failedValidations.isEmpty else {
            return nil
        }
        self.failedValidations = failedValidations
    }

    public func describeFailures(_ describe: (ValidatorFailure) -> String?) -> [(path: String, failures: [String])] {
        failedValidations.compactMap { failedValidation in
            let failures: [String]
            if let failure = failedValidation.failure as? CompoundValidatorFailure {
                failures = failure.failures.flatten().compactMap(describe)
            } else {
                failures = describe(failedValidation.failure).map { [$0] } ?? []
            }
            guard !failures.isEmpty else {
                return nil
            }
            return (failedValidation.path.dotPath, failures)
        }
    }

    public var description: String {
        describeFailures(String.init(describing:))
            .map { path, failures in
                "\(path): \(failures.joined(separator: ", "))"
            }
            .joined(separator: "\n")
    }
}
