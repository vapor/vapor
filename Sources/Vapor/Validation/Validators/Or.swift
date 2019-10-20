/// Combines two `Validator`s, succeeding if either of the `Validator`s does not fail.
public func ||<T> (lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    Validator.Or(lhs: lhs, rhs: rhs).validator()
}

extension Validator {

    /// Combines two validators, if either is true the validation will succeed.
    struct Or: ValidatorType {
        struct Failure: ValidatorFailure {
            let left: ValidatorFailure
            let right: ValidatorFailure
        }

        /// left validator
        let lhs: Validator<T>

        /// right validator
        let rhs: Validator<T>

        public init(lhs: Validator<T>, rhs: Validator<T>) {
            self.lhs = lhs
            self.rhs = rhs
        }

        /// See Validator.validate
        public func validate(_ data: T) -> Failure? {
            switch (lhs.validate(data), rhs.validate(data)) {
            case let (.some(left), .some(right)): return .init(left: left, right: right)
            default: return nil
            }
        }
    }
}

extension Validator.Or.Failure: CustomStringConvertible {
    public var description: String {
        """
        \((left as? CustomStringConvertible)?.description ?? "left validation failed")\
         and \
        \((right as? CustomStringConvertible)?.description ?? "right validation failed")
        """
    }
}
