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

    /// Validates whether a string is a valid email address.
    public struct URL: ValidatorType {
        public struct Result: ValidatorResult {
            /// See `CustomStringConvertible`.
            public let description = "a valid URL"

            /// See `ValidatorResult`.
            public let failed: Bool
        }

        public init() {}

        /// See `Validator`.
        public func validate(_ data: String) -> Result {
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
