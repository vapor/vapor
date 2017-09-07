/// A validator that keeps track of all validation errors
public class Validator : Encodable, Error {
    /// A list of all found validation errros
    public private(set) var errors: [ErrorMessage] = []
    
    public init() {}
    
    /// Asserts that the contents of this variable is `nil`
    @discardableResult
    public func assertNil<T : Encodable>(_ value: T?) -> ErrorMessage? {
        guard let value = value else {
            return nil
        }
        
        return assert(NilValidatorError.notNil(value))
    }
    
    /// Asserts that the contents of this variable is not `nil`
    @discardableResult
    public func assertNotNil<T : Encodable>(_ value: T?) -> ErrorMessage? {
        guard value == nil else {
            return nil
        }
        
        return assert(NilValidatorError.isNil(T.self))
    }
    
    /// Asserts no error occurred
    @discardableResult
    public func assert(_ error: EncodableError?) -> ErrorMessage? {
        guard let error = error else {
            return nil
        }
        
        let message = ErrorMessage(for: error)
        errors.append(message)
        return message
    }
    
    /// Asserts the condition is false
    @discardableResult
    public func assertFalse(_ bool: Bool) -> ErrorMessage? {
        guard bool else {
            return nil
        }
        
        return assert(EqualityError(subject: bool, problem: .notEqual, other: false))
    }
    
    /// Asserts the condition is true
    @discardableResult
    public func assertTrue(_ bool: Bool) -> ErrorMessage? {
        guard !bool else {
            return nil
        }
        
        return assert(EqualityError(subject: bool, problem: .notEqual, other: true))
    }
    
    /// Asserts the condition is true
    public func validate(_ validatable: Validatable) throws {
        try validatable.validate(loggingTo: self)
    }
}
