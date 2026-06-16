#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Validator where T == String {
    /// Validates whether a `String` is a valid email address.
    public static var email: Validator<T> {
        .init {
            guard
                $0.wholeMatch(of: emailRegex) != nil,
                // https://emailregex.com/email-validation-summary
                $0.count <= 320, // total length
                $0.split(separator: "@")[0].count <= 64 // length before `@`
            else {
                return ValidatorResults.Email(isValidEmail: false)
            }
            return ValidatorResults.Email(isValidEmail: true)
        }
    }

    public static var internationalEmail: Validator<T> {
        .init {
            guard
                $0.wholeMatch(of: internationalEmailRegex) != nil,
                // https://emailregex.com/email-validation-summary/
                $0.count <= 320, // total length
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

nonisolated(unsafe) private let emailRegex = #/(?:[a-zA-Z0-9!#$%\&'*+/=?\^_`{|}~-]+(?:\.[a-zA-Z0-9!#$%\&'*+/=?\^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])/#

// Local part: Unicode letters/marks/digits plus the permitted ASCII specials, with no leading or consecutive dots.
// Domain: Unicode letters/marks/digits, hyphens and dots, ending in one or more
// dotted labels of 2–63 letters. Expressed with Unicode property classes (`\p{L}` etc.) because the
// equivalent explicit scalar-block ranges cannot be parsed by Swift's grapheme-aware `Regex`.
nonisolated(unsafe) private let internationalEmailRegex = #/^(?!\.)(?!.*\.{2})[\p{L}\p{M}\p{Nd}.!#$%&'*+\-/=?^_`{|}~]+@(?!\.)[\p{L}\p{M}\p{Nd}.\-]+(?:\.[\p{L}\p{M}]{2,63})+$/#
