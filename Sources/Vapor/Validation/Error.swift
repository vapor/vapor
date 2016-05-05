public protocol ValidationErrorProtocol: ErrorProtocol {
    var message: String { get }
}

/**
    Failure object for validation operations
*/
public class ValidationError<ValidatorType: Validator>: ValidationErrorProtocol {
    public let input: ValidatorType.InputType?
    public let validator: ValidatorType?
    public let message: String

    public init(_ validator: ValidatorType, input: ValidatorType.InputType?, message: String? = nil) {
        self.input = input
        self.validator = validator

        let inputDescription = input.flatMap { "\($0)" } ?? "nil"
        self.message = message ?? "\(validator) failed with input: \(inputDescription)"
    }

    public init(_ type: ValidatorType.Type = ValidatorType.self,
                input: ValidatorType.InputType?,
                message: String? = nil) {
        self.input = input
        self.validator = nil

        let inputDescription = input.flatMap { "\($0)" } ?? "nil"
        self.message = message ?? "\(type) failed with input: \(inputDescription)"
    }
}

extension Validator {
    /**
        Use this to conveniently throw errors within a ValidationSuite
        to indicate the point of failure.

        - parameter input: the value that caused the failure

        - returns: a ValidationFailure object to throw
    */
    public static func error(with input: InputType, message: String? = nil) -> ErrorProtocol {
        return ValidationError(self, input: input, message: message)
    }

    /**
        Use this to conveniently throw errors within a Validator
        to indicate a point of failure

        - parameter input: the value that caused the failure

        - returns: a ValidationFailure object to throw
    */
    public func error(with input: InputType, message: String? = nil) -> ErrorProtocol {
        return ValidationError(self, input: input, message: message)
    }
}
