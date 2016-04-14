/**
 Failure object for basic failures that aren't 
 part of a validation operation
 */
public class Failure<T: Validatable>: ErrorProtocol {
    public let input: T?
    public var name: String
    public init(name: String, input: T?) {
        self.input = input
        self.name = name
    }
}

/**
 Failure object for failures during a validation
 operation.
 
 To throw within a custom Validator, use:
     
     throw error(with: value)
 */
public final class ValidationFailure<V: Validator>: Failure<V.InputType> {
    public init(_ validator: V.Type = V.self, name: String, input: V.InputType?) {
        super.init(name: name, input: input)
    }
    public init(_ validator: V, name: String, input: V.InputType?) {
        super.init(name: name, input: input)
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
        return ValidationFailure(self, name: "Input", input: input)
    }

    /**
     Use this to conveniently throw errors within a Validator
     to indicate a point of failure

     - parameter input: the value that caused the failure

     - returns: a ValidationFailure object to throw
     */
    public func error(with input: InputType) -> ErrorProtocol {
        return ValidationFailure(self, name: "Input", input: input)
    }
}
