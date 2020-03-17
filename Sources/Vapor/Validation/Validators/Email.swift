extension Validator where T == String {
    /// Validates whether a `String` is a valid email address.
    public static var email: Validator<T> {
        .init {
            guard
                let range = $0.range(of: regex, options: [.regularExpression]),
                range.lowerBound == $0.startIndex && range.upperBound == $0.endIndex,
                // FIXME: these numbers are incorrect and too restrictive
                $0.count <= 80, // total length
                $0.split(separator: "@")[0].count <= 64 // length before `@`
            else {
                return ValidatorResults.Email(isValidEmail: false)
            }
            return ValidatorResults.Email(isValidEmail: true)
        }
    }
}

extension ValidatorResults {
    /// `ValidatorResult` of a validator that validates whether a `String` is a valid email address.
    public struct Email {
        /// The input is a valid email address
        public let isValidEmail: Bool
    }
}

extension ValidatorResults.Email: ValidatorResult {
    public var isFailure: Bool {
        !self.isValidEmail
    }
    
    public var successDescription: String? {
        "is a valid email address"
    }
    
    public var failureDescription: String? {
        "is not a valid email address"
    }
}

// FIXME: this regex is too strict with capitalization of the domain part
private let regex: String = """
(?:[a-zA-Z0-9!#$%\\&‘*+/=?\\^_`{|}~-]+(?:\\.[a-zA-Z0-9!#$%\\&'*+/=?\\^_`{|}\
~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\\
x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-\
z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5\
]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-\
9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\
-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])
"""
