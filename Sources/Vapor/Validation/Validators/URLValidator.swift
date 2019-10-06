extension Validator where T == String {
    /// Validates whether a `String` is a valid URL.
    ///
    /// This validator will allow either file URLs, or URLs
    /// containing at least a scheme and a host.
    ///
    public static var url: Validator<T> {
        return URLValidator().validator()
    }
}

public struct URLValidatorFailure: ValidatorFailure {}

/// Validates whether a string is a valid email address.
struct URLValidator: ValidatorType {

    /// See `Validator`.
    func validate(_ data: String) -> URLValidatorFailure? {
        guard
            let url = URL(string: data),
            url.isFileURL || (url.host != nil && url.scheme != nil)
        else {
            return .init()
        }
        return nil
    }
}
