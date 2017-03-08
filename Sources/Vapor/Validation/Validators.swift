/// An object that can be used to validate other objects
public protocol Validator {
    /// The supported input type for this validator
    associatedtype Input: Validatable

    /// The validation function, throw on failed validation with `throw error("reason")`
    func validate(_ input: Input) throws
}

extension Validator {
    /// On validation failure, use this to indicate
    /// why validation failed
    public func error(_ reason: String) -> Error {
        let type = String(describing: type(of: self))
        return ValidatorError.failure(type: type, reason: reason)
    }
}

extension Validator {
    /// Convert throwing function to optional while providing error -- internal only
    internal func validate(_ input: Input, with validator: (Input) throws -> ()) -> Error? {
        do {
            try validator(input)
            return nil
        } catch {
            return error
        }
    }
}
