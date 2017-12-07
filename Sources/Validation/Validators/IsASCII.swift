import Foundation

/// Validates whether a string contains only ASCII characters
public struct IsASCII: Validator {
    /// See Validator.inverseMessage
    public var inverseMessage: String {
        return "ASCII"
    }

    /// creates a new ASCII validator
    public init() {}

    /// See Validator.validate
    public func validate(_ data: ValidationData) throws {
        switch data {
        case .string(let s):
            guard s.range(of: "^[ -~]+$", options: [.regularExpression, .caseInsensitive]) != nil else {
                throw BasicValidationError("is not ASCII")
            }
        default:
            throw BasicValidationError("is not a string")
        }
    }
}
