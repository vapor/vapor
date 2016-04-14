
/**
 Failure object for basic failures that aren't 
 part of a validation operation
 */
public class Failure<T: Validatable>: ErrorProtocol {
    public let input: T?
    public init(input: T?) {
        self.input = input
    }
}

/**
 Failure object for failures during a validation
 operation.
 
 To throw within a custom Validator, use:
     
     throw error(with: value)
 */
public final class ValidationFailure<V: Validator>: Failure<V.InputType> {
    public init(_ validator: V.Type = V.self, input: V.InputType?) {
        super.init(input: input)
    }
    public init(_ validator: V, input: V.InputType?) {
        super.init(input: input)
    }
}

extension Validator {
    /**
     Use this to conveniently throw errors within a ValidationSuite
     to indicate the point of failure.

     - parameter input: the value that caused the failure

     - returns: a ValidationFailure object to throw
     */
    public static func error(with input: InputType) -> ErrorProtocol {
        return ValidationFailure(self, input: input)
    }

    /**
     Use this to conveniently throw errors within a Validator
     to indicate a point of failure

     - parameter input: the value that caused the failure

     - returns: a ValidationFailure object to throw
     */
    public func error(with input: InputType) -> ErrorProtocol {
        return ValidationFailure(self, input: input)
    }
}
