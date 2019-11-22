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
    struct NilIgnoring {
        let base: Validator<T>
    }
}

extension Validator.NilIgnoring: ValidatorType {
    func validate(_ data: T?) -> ValidatorResult {
        ValidatorResults.NilIgnoring(result: data.flatMap(self.base.validate))
    }
}

extension ValidatorResults {
    /// `ValidatorResult` of a validator that ignores nil values.
    public struct NilIgnoring {
        /// Result of a validation or nil if the input is nil.
        public let result: ValidatorResult?
    }
}

extension ValidatorResults.NilIgnoring: ValidatorResult {
    public var isFailure: Bool {
        result?.isFailure == true
    }
    
    public var successDescription: String? {
        self.result?.successDescription
    }
    
    public var failureDescription: String? {
        self.result?.failureDescription
    }
}
