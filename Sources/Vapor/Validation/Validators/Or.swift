/// Combines two `Validator`s, succeeding if either of the `Validator`s does not fail.
public func ||<T> (lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    Validator.Or(lhs: lhs, rhs: rhs).validator()
}

extension Validator {

    /// Combines two validators, if either is true the validation will succeed.
    struct Or: ValidatorType {
        public struct Result: ValidatorResult {
            public let left: ValidatorResult
            public let right: ValidatorResult

            /// See `CustomStringConvertible`.
            public var description: String {
                "\(left.failed ? "not " : "")\(left) and \(right.failed ? "not " : "")\(right)"
            }

            /// See `ValidatorResult`.
            public var failed: Bool { left.failed && right.failed }
        }

        let lhs: Validator<T>
        let rhs: Validator<T>

        public init(lhs: Validator<T>, rhs: Validator<T>) {
            self.lhs = lhs
            self.rhs = rhs
        }

        /// See Validator.validate
        public func validate(_ data: T) -> Result {
            .init(left: lhs.validate(data), right: rhs.validate(data))
        }
    }
}
