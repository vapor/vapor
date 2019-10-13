/// Combines two `Validator`s using AND logic, succeeding if both `Validator`s succeed without error.
public func && <T: Decodable>(lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    Validator.And(lhs: lhs, rhs: rhs).validator()
}

extension Validator {
    public struct And: ValidatorType {
        let lhs: Validator<T>
        let rhs: Validator<T>

        public init(lhs: Validator<T>, rhs: Validator<T>) {
            self.lhs = lhs
            self.rhs = rhs
        }

        public func validate(_ data: T) -> CompoundValidatorFailure? {
            let failures = [lhs.validate(data), rhs.validate(data)].compactMap { $0 }
            guard failures.isEmpty else {
                return Failure(failures: failures)
            }
            return nil
        }
    }
}
