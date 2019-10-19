extension Validator where T == String {

    /// Validates whether a `String` is a valid URL.
    ///
    /// This validator will allow either file URLs, or URLs
    /// containing at least a scheme and a host.
    ///
    public static var url: Validator<T> {
        URL().validator()
    }

    /// Validates whether a string is a valid email address.
    public struct URL: ValidatorType {
        public struct Failure: ValidatorFailure {}

        public init() {}

        /// See `Validator`.
        public func validate(_ data: String) -> Failure? {
            guard
                let url = Foundation.URL(string: data),
                url.isFileURL || (url.host != nil && url.scheme != nil)
            else {
                return .init()
            }
            return nil
        }
    }
}

extension Validator.URL.Failure: CustomStringConvertible {

    /// See `CustomStringConvertible`.
    public var description: String {
        "is not a valid URL"
    }
}
