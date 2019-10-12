/// Combines two `Validator`s, succeeding if either of the `Validator`s does not fail.
public func ||<T> (lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    Validator.Or(lhs: lhs, rhs: rhs).validator()
}

extension Validator {

    /// Combines two validators, if either is true the validation will succeed.
    struct Or: ValidatorType {
        /// left validator
        let lhs: Validator<T>

        /// right validator
        let rhs: Validator<T>

        public init(lhs: Validator<T>, rhs: Validator<T>) {
            self.lhs = lhs
            self.rhs = rhs
        }

        /// See Validator.validate
        public func validate(_ data: T) -> CompoundValidatorFailure? {
            let failures = [lhs.validate(data), rhs.validate(data)].compactMap { $0 }
            guard failures.count != 2 else {
                return .init(failures: failures)
            }
            return nil
        }
    }
}
