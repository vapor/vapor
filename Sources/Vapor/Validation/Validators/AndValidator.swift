/// Combines two `Validator`s using AND logic, succeeding if both `Validator`s succeed without error.
public func && <T: Decodable>(lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    AndValidator(lhs: lhs, rhs: rhs).validator()
}

struct AndValidator<T: Decodable>: ValidatorType {
    let lhs: Validator<T>
    let rhs: Validator<T>

    func validate(_ data: T) -> CompoundValidatorFailure? {
        let failures = [lhs.validate(data), rhs.validate(data)].compactMap { $0 }
        guard failures.isEmpty else {
            return Failure(failures: failures)
        }
        return nil
    }
}
