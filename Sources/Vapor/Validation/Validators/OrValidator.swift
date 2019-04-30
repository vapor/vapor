/// Combines two `Validator`s, succeeding if either of the `Validator`s does not fail.
///
///     // validate email is valid or is nil
///     try validations.add(\.email, .email || .nil)
///
public func ||<T> (lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    return OrValidator(lhs, rhs).validator()
}

// MARK: Private

/// Combines two validators, if either is true the validation will succeed.
private struct OrValidator<T>: ValidatorType where T: Codable {
    /// See Validator.inverseMessage
    public var validatorReadable: String {
        return "\(lhs.readable) or is \(rhs.readable)"
    }

    /// left validator
    let lhs: Validator<T>

    /// right validator
    let rhs: Validator<T>

    /// Creates a new `OrValidator`.
    init(_ lhs: Validator<T>, _ rhs: Validator<T>) {
        self.lhs = lhs
        self.rhs = rhs
    }

    /// See Validator.validate
    func validate(_ data: T) -> ValidatorFailure? {
        let left = self.lhs.validate(data)
        let right = self.rhs.validate(data)
        switch (left, right) {
        case (.none, .none), (.some, .none), (.none, .some): return nil
        case (.some(let left), .some(let right)):
            return .init("\(left) and \(right)")
        }
    }
}
