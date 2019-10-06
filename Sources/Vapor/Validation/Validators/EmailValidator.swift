extension Validator where T == String {
    /// Validates whether a `String` is a valid email address.
    public static var email: Validator<T> {
        EmailValidator().validator()
    }
}

public struct EmailValidatorFailure: ValidatorFailure {}

/// Validates whether a string is a valid email address.
struct EmailValidator: ValidatorType {

    static let regex: String = """
    (?:[a-zA-Z0-9!#$%\\&‘*+/=?\\^_`{|}~-]+(?:\\.[a-zA-Z0-9!#$%\\&'*+/=?\\^_`{|}\
    ~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\\
    x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-\
    z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5\
    ]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-\
    9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\
    -\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])
    """

    /// See `Validator`.
    func validate(_ s: String) -> EmailValidatorFailure? {
        guard
            let range = s.range(of: EmailValidator.regex, options: [.regularExpression]),
            range.lowerBound == s.startIndex && range.upperBound == s.endIndex,
            s.count <= 80, // total length
            s.split(separator: "@")[0].count <= 64 // length before `@`
        else {
            return .init()
        }

        return nil
    }
}
