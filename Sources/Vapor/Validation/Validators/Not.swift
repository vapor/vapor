/// Inverts a `Validation`.
public prefix func !<T: Decodable> (validator: Validator<T>) -> Validator<T> {
    Validator.Not(validator: validator).validator()
}

extension Validator {

    /// Inverted `ValidatorResult`.
    public struct NotValidatorResult: ValidatorResult {

        /// The inverted `ValidatorResult`.
        public let inverted: ValidatorResult

        /// See `CustomStringConvertible`.
        public var description: String { "not \(inverted)" }

        /// See `ValidatorResult`.
        public var failed: Bool { !inverted.failed }
    }

    struct Not: ValidatorType {
        let validator: Validator<T>

        func validate(_ data: T) -> NotValidatorResult {
            .init(inverted: validator.validate(data))
        }
    }
}
