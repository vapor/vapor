/**
    Failure object for basic failures that aren't
    part of a validation operation
*/
public class Failure: ErrorProtocol {
    public let name: String
    public let inputDescription: String

    public init(name: String = "", input: String?) {
        self.name = name
        self.inputDescription = input ?? "nil"
    }
}

/**
    Failure object for failures during a validation
    operation.

    To throw within a custom Validator, use:
     
     throw error(with: value)
*/
public final class ValidationFailure: Failure {
    let validator: String
    public init<V: Validator>(_ validator: V.Type = V.self, input: V.InputType?) {
        self.validator = "\(V.self)"
        super.init(input: "\(input)")
    }
    public init<V: Validator>(_ validator: V, input: V.InputType?) {
        self.validator = "\(V.self)"
        super.init(input: "\(input)")
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
