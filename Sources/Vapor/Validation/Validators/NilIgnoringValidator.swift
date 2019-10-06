/// Combines an optional and non-optional `Validator` using OR logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
public func ||<T> (lhs: Validator<T?>, rhs: Validator<T>) -> Validator<T?> {
    lhs || NilIgnoringValidator(rhs).validator()
}

/// Combines an optional and non-optional `Validator` using OR logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
public func ||<T> (lhs: Validator<T>, rhs: Validator<T?>) -> Validator<T?> {
    NilIgnoringValidator(lhs).validator() || rhs
}

/// Combines an optional and non-optional `Validator` using AND logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
public func &&<T> (lhs: Validator<T?>, rhs: Validator<T>) -> Validator<T?> {
    lhs && NilIgnoringValidator(rhs).validator()
}

/// Combines an optional and non-optional `Validator` using AND logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
public func &&<T> (lhs: Validator<T>, rhs: Validator<T?>) -> Validator<T?> {
    NilIgnoringValidator(lhs).validator() && rhs
}

/// A validator that ignores nil values.
struct NilIgnoringValidator<T>: ValidatorType where T: Decodable {
    /// right validator
    let base: Validator<T>

    /// Creates a new `NilIgnoringValidator`.
    init(_ base: Validator<T>) {
        self.base = base
    }

    /// See `ValidatorType`.
    func validate(_ data: T?) -> CompoundValidatorFailure? {
        if let failure = data.flatMap(base.validate) {
            return .init(failures: [failure])
        }
        return nil
    }
}
