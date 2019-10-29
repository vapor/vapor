/// Inverts a `Validation`.
public prefix func !<T: Decodable> (validator: Validator<T>) -> Validator<T> {
    Validator.Not(validator: validator).validator()
}

extension Validator {

    /// Inverts a validator.
    struct Not: ValidatorType {
        struct Result: ValidatorResult {
            let inverted: ValidatorResult

            /// See `CustomStringConvertible`.
            var description: String { "not \(inverted)" }

            /// See `ValidatorResult`.
            var failed: Bool { !inverted.failed }
        }

        /// The inverted `Validator`.
        let validator: Validator<T>

        /// See `ValidatorType`
        func validate(_ data: T) -> Result {
            .init(inverted: validator.validate(data))
        }
    }
}
