/// Combines an optional and non-optional `Validator` using OR logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
public func ||<T> (lhs: Validator<T?>, rhs: Validator<T>) -> Validator<T?> {
    lhs || Validator.NilIgnoring(rhs).validator()
}

/// Combines an optional and non-optional `Validator` using OR logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
public func ||<T> (lhs: Validator<T>, rhs: Validator<T?>) -> Validator<T?> {
    Validator.NilIgnoring(lhs).validator() || rhs
}

/// Combines an optional and non-optional `Validator` using AND logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
public func &&<T> (lhs: Validator<T?>, rhs: Validator<T>) -> Validator<T?> {
    lhs && Validator.NilIgnoring(rhs).validator()
}

/// Combines an optional and non-optional `Validator` using AND logic. The non-optional
/// validator will simply ignore `nil` values, assuming the other `Validator` handles them.
public func &&<T> (lhs: Validator<T>, rhs: Validator<T?>) -> Validator<T?> {
    Validator.NilIgnoring(lhs).validator() && rhs
}

extension Validator {

    /// A validator that ignores nil values.
    public struct NilIgnoring: ValidatorType {
        public struct Result: ValidatorResult {
            let result: ValidatorResult?

            /// See `CustomStringConvertible`.
            public var description: String { result?.description ?? "nil" }

            /// See `ValidatorResult`.
            public var failed: Bool { result?.failed == true }
        }

        let base: Validator<T>

        /// Creates a new `NilIgnoringValidator`.
        public init(_ base: Validator<T>) {
            self.base = base
        }

        /// See `ValidatorType`.
        public func validate(_ data: T?) -> Result {
            .init(result: data.flatMap(base.validate))
        }
    }
}
