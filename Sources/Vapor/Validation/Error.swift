public class Failure<T: Validatable>: ErrorProtocol {
    public let input: T?
    public init(input: T?) {
        self.input = input
    }
}

public class ValidationFailure<V: Validator>: Failure<V.InputType> {
    public init(_ validator: V.Type = V.self, input: V.InputType) {
        super.init(input: input)
    }
    public init(_ validator: V, input: V.InputType) {
        super.init(input: input)
    }
}

extension Validator {
    public static func error(with input: InputType) -> ErrorProtocol {
        return ValidationFailure(self, input: input)
    }
    public func error(with input: InputType) -> ErrorProtocol {
        return ValidationFailure(self, input: input)
    }
}
