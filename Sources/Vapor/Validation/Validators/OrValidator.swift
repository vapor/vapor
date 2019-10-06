/// Combines two `Validator`s, succeeding if either of the `Validator`s does not fail.
public func ||<T> (lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    return OrValidator(lhs: lhs, rhs: rhs).validator()
}

/// Combines two validators, if either is true the validation will succeed.
struct OrValidator<T: Decodable>: ValidatorType {
    /// left validator
    let lhs: Validator<T>

    /// right validator
    let rhs: Validator<T>

    /// See Validator.validate
    func validate(_ data: T) -> CompoundValidatorFailure? {
        let failures = [lhs.validate(data), rhs.validate(data)].compactMap { $0 }
        guard failures.count != 2 else {
            return .init(failures: failures)
        }
        return nil
    }
}
