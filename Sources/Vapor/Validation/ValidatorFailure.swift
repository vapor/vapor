public protocol ValidatorFailure {}

public struct CompoundValidatorFailure: ValidatorFailure {
    public var failures: [ValidatorFailure]

    public init(failures: [ValidatorFailure]) {
        self.failures = failures
    }
}

extension Sequence where Element == ValidatorFailure {
    func flatten() -> [ValidatorFailure] {
        flatMap { failure -> [ValidatorFailure] in
            if let failure = failure as? CompoundValidatorFailure {
                return failure.failures.flatten()
            } else {
                return [failure]
            }
        }
    }
}

public struct MissingRequiredValueFailure: ValidatorFailure {}

public struct TypeMismatchValidatorFailure: ValidatorFailure {}
