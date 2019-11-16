/// Combines an optional and non-optional `Validator` using OR logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
public func ||<T> (lhs: Validator<T?>, rhs: Validator<T>) -> Validator<T?> {
    lhs || Validator.NilIgnoring(base: rhs).validator()
}

/// Combines an optional and non-optional `Validator` using OR logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
public func ||<T> (lhs: Validator<T>, rhs: Validator<T?>) -> Validator<T?> {
    Validator.NilIgnoring(base: lhs).validator() || rhs
}

/// Combines an optional and non-optional `Validator` using AND logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
public func &&<T> (lhs: Validator<T?>, rhs: Validator<T>) -> Validator<T?> {
    lhs && Validator.NilIgnoring(base: rhs).validator()
}

/// Combines an optional and non-optional `Validator` using AND logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
public func &&<T> (lhs: Validator<T>, rhs: Validator<T?>) -> Validator<T?> {
    Validator.NilIgnoring(base: lhs).validator() && rhs
}

extension Validator {

    /// `ValidatorResult` of a validator that ignores nil values.
    public struct NilIgnoringValidatorResult: ValidatorResult {

        /// Result of a validation or nil if the input is nil.
        let result: ValidatorResult?

        /// See `CustomStringConvertible`.
        public var description: String { result?.description ?? "nil" }

        /// See `ValidatorResult`.
        public var failed: Bool { result?.failed == true }
    }

    struct NilIgnoring: ValidatorType {
        let base: Validator<T>

        func inverted() -> NilIgnoring {
            .init(base: base.inverted())
        }

        func validate(_ data: T?) -> NilIgnoringValidatorResult {
            .init(result: data.flatMap(base.validate))
        }
    }
}
