/// Checks whether a child validatable object
/// passes its validations.
public struct IsValid: Validator {
    /// See Validator.inverseMessage
    public var inverseMessage: String {
        return "valid"
    }

    /// Create a new is valid validator
    public init() {}

    /// See Validator.validate
    public func validate(_ data: ValidationData) throws  {
        switch data {
        case .validatable(let v):
            try v.validate()
        default:
            throw BasicValidationError("is invalid")
        }
    }
}
