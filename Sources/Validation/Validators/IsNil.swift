/// Validates that the data is nil
public struct IsNil: Validator {
    /// See Validator.inverseMessage
    public var inverseMessage: String {
        return "nil"
    }

    /// Creates a new is nil validator
    public init() {}

    /// See Validator.validate
    public func validate(_ data: ValidationData) throws {
        switch data {
        case .null: break
        default: throw BasicValidationError("is not nil")
        }
    }
}
