/// Inverts a `Validation`.
///
///     try validations.add(\.email, .email && !.nil)
///
public prefix func !<T> (rhs: Validator<T>) -> Validator<T> {
    return NotValidator(rhs).validator()
}

// MARK: Private

/// Inverts a validator
private struct NotValidator<T>: ValidatorType where T: Codable {
    /// See `ValidatorType`.
    typealias ValidationData = T

    /// See `ValidatorType`
    public var validatorReadable: String {
        return "not \(rhs.readable)"
    }

    /// The inverted `Validator`.
    let rhs: Validator<T>

    /// Creates a new `NotValidator`.
    init(_ rhs: Validator<T>) {
        self.rhs = rhs
    }

    /// See `ValidatorType`
    func validate(_ data: T) -> ValidatorFailure? {
        if self.rhs.validate(data) == nil {
            return .init("is \(self.rhs)")
        }
        return nil
    }
}
