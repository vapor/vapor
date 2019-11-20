/// Combines two `Validator`s, succeeding if either of the `Validator`s does not fail.
public func ||<T> (lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    Validator.Or(lhs: lhs, rhs: rhs).validator()
}

extension Validator {

    /// `ValidatorResult` of "Or" `Validator` that combines two `ValidatorResults`.
    /// If either result is successful the combined result is as well.
    public struct OrValidatorResult: ValidatorResult {

        /// `ValidatorResult` of left hand side.
        public let left: ValidatorResult

        /// `ValidatorResult` of right hand side.
        public let right: ValidatorResult

        /// See `CustomStringConvertible`.
        public var description: String { "\(left) and \(right)" }

        /// See `ValidatorResult`.
        public var failed: Bool { left.failed && right.failed }
    }

    struct Or: ValidatorType {
        let lhs: Validator<T>
        let rhs: Validator<T>

        func inverted() -> And {
            .init(lhs: lhs.inverted(), rhs: rhs.inverted())
        }

        func validate(_ data: T) -> OrValidatorResult {
            .init(left: lhs.validate(data), right: rhs.validate(data))
        }
    }
}
