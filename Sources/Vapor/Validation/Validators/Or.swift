/// Combines two `Validator`s, succeeding if either of the `Validator`s does not fail.
public func ||<T> (lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    Validator.Or(lhs: lhs, rhs: rhs).validator()
}

extension Validator {

    /// `ValidatorResult` of "Or" `Validator` that combines two `ValidatorResults`.
    /// If either result is successful the combined result is as well.
    public struct OrValidatorResult: ValidatorResult {

        /// `ValidatorResult` of left hand side of the "Or" validation.
        public let left: ValidatorResult

        /// `ValidatorResult` of right hand side of the "Or" validation.
        public let right: ValidatorResult

        /// See `CustomStringConvertible`.
        public var description: String {
            "\(left.failed ? "not " : "")\(left) and \(right.failed ? "not " : "")\(right)"
        }

        /// See `ValidatorResult`.
        public var failed: Bool { left.failed && right.failed }
    }

    struct Or: ValidatorType {
        let lhs: Validator<T>
        let rhs: Validator<T>

        func validate(_ data: T) -> OrValidatorResult {
            .init(left: lhs.validate(data), right: rhs.validate(data))
        }
    }
}
