import Foundation

private let alphanumeric = "abcdefghijklmnopqrstuvwxyz0123456789"

/// Validates whether a string contains only alphanumeric characters
public struct IsAlphanumeric: Validator {
    /// See Validator.inverseMessage
    public var inverseMessage: String {
        return "alphanumeric"
    }

    /// creates a new alphanumeric validator
    public init() {}

    /// See Validator.validate
    public func validate(_ data: ValidationData) throws {
        switch data {
        case .string(let s):
            for char in s.lowercased() {
                guard alphanumeric.contains(char) else {
                    throw BasicValidationError("is not alphanumeric")
                }
            }
        default: throw BasicValidationError("is not a string")
        }
    }
}
