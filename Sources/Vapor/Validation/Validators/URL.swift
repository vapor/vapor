extension Validator where T == String {

    /// Validates whether a `String` is a valid URL.
    ///
    /// This validator will allow either file URLs, or URLs
    /// containing at least a scheme and a host.
    ///
    public static var url: Validator<T> {
        URL().validator()
    }
}

extension Validator {

    /// `ValidatorResult` of a validator that validates whether a string is a valid URL.
    public struct URLValidatorResult: ValidatorResult {

        /// See `CustomStringConvertible`.
        public let description = "a valid URL"

        /// See `ValidatorResult`.
        public let failed: Bool
    }

    struct URL: ValidatorType {
        func validate(_ data: String) -> URLValidatorResult {
            guard
                let url = Foundation.URL(string: data),
                url.isFileURL || (url.host != nil && url.scheme != nil)
            else {
                return .init(failed: true)
            }
            return .init(failed: false)
        }
    }
}
