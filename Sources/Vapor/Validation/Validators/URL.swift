extension Validator where T == String {

    /// Validates whether a `String` is a valid URL.
    ///
    /// This validator will allow either file URLs, or URLs
    /// containing at least a scheme and a host.
    ///
    public static var url: Validator<T> {
        URL(isInverted: false).validator()
    }
}

extension Validator {

    /// `ValidatorResult` of a validator that validates whether a string is a valid URL.
    public struct URLValidatorResult: ValidatorResult {

        /// The input is a valid URL.
        let isValidURL: Bool

        /// Inverts the `failed` state.
        let isInverted: Bool

        /// See `CustomStringConvertible`.
        public var description: String { "a\(isValidURL ? " " : "n in")valid URL" }

        /// See `ValidatorResult`.
        public var failed: Bool { isValidURL == isInverted }
    }

    struct URL: ValidatorType {
        let isInverted: Bool

        func inverted() -> URL {
            .init(isInverted: !isInverted)
        }

        func validate(_ data: String) -> URLValidatorResult {
            guard
                let url = Foundation.URL(string: data),
                url.isFileURL || (url.host != nil && url.scheme != nil)
            else {
                return .init(isValidURL: false, isInverted: isInverted)
            }
            return .init(isValidURL: true, isInverted: isInverted)
        }
    }
}
