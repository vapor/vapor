/// Combines an optional and non-optional `Validator` using OR logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
///
///     try validations.add(\.email, .nil || .email)
///
public func ||<T> (lhs: Validator<T?>, rhs: Validator<T>) -> Validator<T?> {
    return lhs || NilIgnoringValidator(rhs).validator()
}

/// Combines an optional and non-optional `Validator` using OR logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
///
///     try validations.add(\.email, .nil || .email)
///
public func ||<T> (lhs: Validator<T>, rhs: Validator<T?>) -> Validator<T?> {
    return NilIgnoringValidator(lhs).validator() || rhs
}

/// Combines an optional and non-optional `Validator` using AND logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
///
///     try validations.add(\.email, !.nil && .email)
///
public func &&<T> (lhs: Validator<T?>, rhs: Validator<T>) -> Validator<T?> {
    return lhs && NilIgnoringValidator(rhs).validator()
}

/// Combines an optional and non-optional `Validator` using AND logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
///
///     try validations.add(\.email, !.nil && .email)
///
public func &&<T> (lhs: Validator<T>, rhs: Validator<T?>) -> Validator<T?> {
    return NilIgnoringValidator(lhs).validator() && rhs
}

// MARK: Private

/// A validator that ignores nil values.
fileprivate struct NilIgnoringValidator<T>: ValidatorType where T: Codable {
    /// right validator
    let base: Validator<T>

    /// See `ValidatorType`.
    public var validatorReadable: String {
        return base.readable
    }

    /// Creates a new `NilIgnoringValidator`.
    init(_ base: Validator<T>) {
        self.base = base
    }

    /// See `ValidatorType`.
    func validate(_ data: T?) -> ValidatorFailure? {
        if let data = data {
            return self.base.validate(data)
        } else {
            return nil
        }
    }
}
