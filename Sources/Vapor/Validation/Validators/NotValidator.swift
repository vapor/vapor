/// Inverts a `Validation`.
public prefix func !<V: ValidatorType> (validator: V) -> Validator<V.Data> {
    NotValidator(validator: validator).validator()
}

public struct NotValidatorFailure<F: ValidatorFailure>: ValidatorFailure {
    let type: F.Type = F.self
}

/// Inverts a validator
struct NotValidator<V: ValidatorType>: ValidatorType {
    /// See `ValidatorType`.

    /// The inverted `Validator`.
    let validator: V

    /// See `ValidatorType`
    func validate(_ data: V.Data) -> NotValidatorFailure<V.Failure>? {
        validator.validate(data) == nil ? .init() : nil
    }
}
