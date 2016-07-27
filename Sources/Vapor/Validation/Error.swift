

/**
    Used to indicate when validation of some value fails. 
 
    Will be caught automatically by ValidationMiddleware
*/
public protocol ValidationErrorProtocol: Swift.Error {
    /**
        Description of what went wrong
    */
    var message: String { get }

    /**
        Description of what went wrong
    */
    var validatorDescription: String { get }

    /**
        Description of failed input
    */
    var inputDescription: String { get }
}

/**
    When a validation fails, usually passed through this protocol from
 
        throw error(with: inputValue)
 
    Will be caught by ValidationMiddleware
*/
public final class ValidationError<ValidatorType: Validator>: ValidationErrorProtocol {

    /**
        Input passed into validation
    */
    public let input: ValidatorType.InputType?

    /**
        Validator that raised the error
    */
    public let validator: ValidatorType?

    /**
        Message describing error. This will be passed to user by ValidationMiddleware.
    */
    public let message: String

    /**
        Description of validator or suite
    */
    public var validatorDescription: String {
        return validator.flatMap { "\($0)" } ?? "\(ValidatorType.self)"
    }

    /**
        Description of input
    */
    public var inputDescription: String {
        return input.flatMap { "\($0)" } ?? "nil"
    }

    /**
        Initialize a new validation error

        - parameter validator: validator that failed
        - parameter input: the input type passed
        - parameter message: custom message if desired
     */
    public init(_ validator: ValidatorType,
                input: ValidatorType.InputType?,
                message: String? = nil) {
        self.input = input
        self.validator = validator

        let inputDescription = input.flatMap { "\($0)" } ?? "nil"
        self.message = message ?? "Validating \(validator) failed for input '\(inputDescription)'"
    }

    /**
        Initialize a new validation error

        - parameter type: validation suite that failed
        - parameter input: input that caused the failure
        - parameter message: custom message if desired
     */
    public init(_ type: ValidatorType.Type = ValidatorType.self,
                input: ValidatorType.InputType?,
                message: String? = nil) {
        self.input = input
        self.validator = nil

        let inputDescription = input.flatMap { "\($0)" } ?? "nil"
        self.message = message ?? "Validating \(type) failed for input '\(inputDescription)'"
    }
}

extension Validator {
    /**
        Use this to conveniently throw errors within a ValidationSuite
        to indicate the point of failure.

        - parameter input: the value that caused the failure

        - returns: a ValidationFailure object to throw
    */
    public static func error(with input: InputType, message: String? = nil) -> Swift.Error {
        return ValidationError(self, input: input, message: message)
    }

    /**
        Use this to conveniently throw errors within a Validator
        to indicate a point of failure

        - parameter input: the value that caused the failure

        - returns: a ValidationFailure object to throw
    */
    public func error(with input: InputType, message: String? = nil) -> Swift.Error {
        return ValidationError(self, input: input, message: message)
    }
}
