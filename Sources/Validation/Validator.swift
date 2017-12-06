/// Capable of validating validation data or throwing a validation error
public protocol Validator {
    /// used by the not validator when this
    var inverseMessage: String { get }

    /// validates the supplied data
    func validate(_ data: ValidationData) throws
}
