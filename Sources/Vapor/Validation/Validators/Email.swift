extension Validator where T == String {
    /// Validates whether a `String` is a valid email address.
    public static var email: Validator<T> {
        .init {
            guard
                let range = $0.range(of: regex, options: [.regularExpression]),
                range.lowerBound == $0.startIndex && range.upperBound == $0.endIndex,
                // The numbers beneath here are as defined by https://emailregex.com/email-validation-summary/
                $0.count <= 320,  // total length
                $0.split(separator: "@")[0].count <= 64  // length before `@`
            else {
                return ValidatorResults.Email(isValidEmail: false)
            }
            return ValidatorResults.Email(isValidEmail: true)
        }
    }

    public static var internationalEmail: Validator<T> {
        .init {
            guard
                let range = $0.range(of: regexInternationalEmail, options: [.regularExpression]),
                range.lowerBound == $0.startIndex && range.upperBound == $0.endIndex,
                // The numbers beneath here are as defined by https://emailregex.com/email-validation-summary/
                $0.count <= 320,  // total length
                $0.split(separator: "@")[0].count <= 64  // length before `@`
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

private let regex: String = """
    (?:[a-zA-Z0-9!#$%\\&‘*+/=?\\^_`{|}~-]+(?:\\.[a-zA-Z0-9!#$%\\&'*+/=?\\^_`{|}\
    ~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\\
    x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-zA-Z0-9](?:[a-\
    zA-Z0-9-]*[a-zA-Z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5\
    ]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-\
    9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\
    -\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])
    """

private let regexInternationalEmail: String = """
    ^(?!\\.)((?!.*\\.{2})[a-zA-Z0-9\\u0080-\\u00FF\\u0100-\\u017F\\u0180-\\u024F\\u0250-\\u02AF\\u0300-\\u036F\\u0370-\\u03FF\\u0400-\\u04FF\\u0500-\\u052F\\u0530-\\u058F\\u0590-\\u05FF\\u0600-\\u06FF\\u0700-\\u074F\\u0750-\\u077F\\u0780-\\u07BF\\u07C0-\\u07FF\\u0900-\\u097F\\u0980-\\u09FF\\u0A00-\\u0A7F\\u0A80-\\u0AFF\\u0B00-\\u0B7F\\u0B80-\\u0BFF\\u0C00-\\u0C7F\\u0C80-\\u0CFF\\u0D00-\\u0D7F\\u0D80-\\u0DFF\\u0E00-\\u0E7F\\u0E80-\\u0EFF\\u0F00-\\u0FFF\\u1000-\\u109F\\u10A0-\\u10FF\\u1100-\\u11FF\\u1200-\\u137F\\u1380-\\u139F\\u13A0-\\u13FF\\u1400-\\u167F\\u1680-\\u169F\\u16A0-\\u16FF\\u1700-\\u171F\\u1720-\\u173F\\u1740-\\u175F\\u1760-\\u177F\\u1780-\\u17FF\\u1800-\\u18AF\\u1900-\\u194F\\u1950-\\u197F\\u1980-\\u19DF\\u19E0-\\u19FF\\u1A00-\\u1A1F\\u1B00-\\u1B7F\\u1D00-\\u1D7F\\u1D80-\\u1DBF\\u1DC0-\\u1DFF\\u1E00-\\u1EFF\\u1F00-\\u1FFFu20D0-\\u20FF\\u2100-\\u214F\\u2C00-\\u2C5F\\u2C60-\\u2C7F\\u2C80-\\u2CFF\\u2D00-\\u2D2F\\u2D30-\\u2D7F\\u2D80-\\u2DDF\\u2F00-\\u2FDF\\u2FF0-\\u2FFF\\u3040-\\u309F\\u30A0-\\u30FF\\u3100-\\u312F\\u3130-\\u318F\\u3190-\\u319F\\u31C0-\\u31EF\\u31F0-\\u31FF\\u3200-\\u32FF\\u3300-\\u33FF\\u3400-\\u4DBF\\u4DC0-\\u4DFF\\u4E00-\\u9FFF\\uA000-\\uA48F\\uA490-\\uA4CF\\uA700-\\uA71F\\uA800-\\uA82F\\uA840-\\uA87F\\uAC00-\\uD7AF\\uF900-\\uFAFF\\.!#$%&'*+-/=?^_`{|}~\\-\\d]+)@(?!\\.)([a-zA-Z0-9\\u0080-\\u00FF\\u0100-\\u017F\\u0180-\\u024F\\u0250-\\u02AF\\u0300-\\u036F\\u0370-\\u03FF\\u0400-\\u04FF\\u0500-\\u052F\\u0530-\\u058F\\u0590-\\u05FF\\u0600-\\u06FF\\u0700-\\u074F\\u0750-\\u077F\\u0780-\\u07BF\\u07C0-\\u07FF\\u0900-\\u097F\\u0980-\\u09FF\\u0A00-\\u0A7F\\u0A80-\\u0AFF\\u0B00-\\u0B7F\\u0B80-\\u0BFF\\u0C00-\\u0C7F\\u0C80-\\u0CFF\\u0D00-\\u0D7F\\u0D80-\\u0DFF\\u0E00-\\u0E7F\\u0E80-\\u0EFF\\u0F00-\\u0FFF\\u1000-\\u109F\\u10A0-\\u10FF\\u1100-\\u11FF\\u1200-\\u137F\\u1380-\\u139F\\u13A0-\\u13FF\\u1400-\\u167F\\u1680-\\u169F\\u16A0-\\u16FF\\u1700-\\u171F\\u1720-\\u173F\\u1740-\\u175F\\u1760-\\u177F\\u1780-\\u17FF\\u1800-\\u18AF\\u1900-\\u194F\\u1950-\\u197F\\u1980-\\u19DF\\u19E0-\\u19FF\\u1A00-\\u1A1F\\u1B00-\\u1B7F\\u1D00-\\u1D7F\\u1D80-\\u1DBF\\u1DC0-\\u1DFF\\u1E00-\\u1EFF\\u1F00-\\u1FFF\\u20D0-\\u20FF\\u2100-\\u214F\\u2C00-\\u2C5F\\u2C60-\\u2C7F\\u2C80-\\u2CFF\\u2D00-\\u2D2F\\u2D30-\\u2D7F\\u2D80-\\u2DDF\\u2F00-\\u2FDF\\u2FF0-\\u2FFF\\u3040-\\u309F\\u30A0-\\u30FF\\u3100-\\u312F\\u3130-\\u318F\\u3190-\\u319F\\u31C0-\\u31EF\\u31F0-\\u31FF\\u3200-\\u32FF\\u3300-\\u33FF\\u3400-\\u4DBF\\u4DC0-\\u4DFF\\u4E00-\\u9FFF\\uA000-\\uA48F\\uA490-\\uA4CF\\uA700-\\uA71F\\uA800-\\uA82F\\uA840-\\uA87F\\uAC00-\\uD7AF\\uF900-\\uFAFF\\-\\.\\d]+)((\\.([a-zA-Z\\u0080-\\u00FF\\u0100-\\u017F\\u0180-\\u024F\\u0250-\\u02AF\\u0300-\\u036F\\u0370-\\u03FF\\u0400-\\u04FF\\u0500-\\u052F\\u0530-\\u058F\\u0590-\\u05FF\\u0600-\\u06FF\\u0700-\\u074F\\u0750-\\u077F\\u0780-\\u07BF\\u07C0-\\u07FF\\u0900-\\u097F\\u0980-\\u09FF\\u0A00-\\u0A7F\\u0A80-\\u0AFF\\u0B00-\\u0B7F\\u0B80-\\u0BFF\\u0C00-\\u0C7F\\u0C80-\\u0CFF\\u0D00-\\u0D7F\\u0D80-\\u0DFF\\u0E00-\\u0E7F\\u0E80-\\u0EFF\\u0F00-\\u0FFF\\u1000-\\u109F\\u10A0-\\u10FF\\u1100-\\u11FF\\u1200-\\u137F\\u1380-\\u139F\\u13A0-\\u13FF\\u1400-\\u167F\\u1680-\\u169F\\u16A0-\\u16FF\\u1700-\\u171F\\u1720-\\u173F\\u1740-\\u175F\\u1760-\\u177F\\u1780-\\u17FF\\u1800-\\u18AF\\u1900-\\u194F\\u1950-\\u197F\\u1980-\\u19DF\\u19E0-\\u19FF\\u1A00-\\u1A1F\\u1B00-\\u1B7F\\u1D00-\\u1D7F\\u1D80-\\u1DBF\\u1DC0-\\u1DFF\\u1E00-\\u1EFF\\u1F00-\\u1FFF\\u20D0-\\u20FF\\u2100-\\u214F\\u2C00-\\u2C5F\\u2C60-\\u2C7F\\u2C80-\\u2CFF\\u2D00-\\u2D2F\\u2D30-\\u2D7F\\u2D80-\\u2DDF\\u2F00-\\u2FDF\\u2FF0-\\u2FFF\\u3040-\\u309F\\u30A0-\\u30FF\\u3100-\\u312F\\u3130-\\u318F\\u3190-\\u319F\\u31C0-\\u31EF\\u31F0-\\u31FF\\u3200-\\u32FF\\u3300-\\u33FF\\u3400-\\u4DBF\\u4DC0-\\u4DFF\\u4E00-\\u9FFF\\uA000-\\uA48F\\uA490-\\uA4CF\\uA700-\\uA71F\\uA800-\\uA82F\\uA840-\\uA87F\\uAC00-\\uD7AF\\uF900-\\uFAFF]){2,63})+)$
    """
