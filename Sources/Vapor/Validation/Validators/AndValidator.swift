/// Combines two `Validator`s using AND logic, succeeding if both `Validator`s succeed without error.
///
///     try validations.add(\.name, .range(5...) && .alphanumeric)
///
public func &&<T> (lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    return AndValidator(lhs, rhs).validator()
}

/// Combines two validators, if either both succeed the validation will succeed.
private struct AndValidator<T>: ValidatorType where T: Codable {
    /// See `ValidatorType`.
    public var validatorReadable: String {
        return "\(lhs) and is \(rhs)"
    }

    /// left validator
    let lhs: Validator<T>

    /// right validator
    let rhs: Validator<T>

    /// create a new and validator
    init(_ lhs: Validator<T>, _ rhs: Validator<T>) {
        self.lhs = lhs
        self.rhs = rhs
    }

    /// See `ValidatorType`.
    func validate(_ data: T) -> ValidatorFailure? {
        if let error = self.lhs.validate(data) {
            return error
        }
        if let error = self.rhs.validate(data) {
            return error
        }
        return nil
    }
}
