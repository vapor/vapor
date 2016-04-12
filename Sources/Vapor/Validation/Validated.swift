
public struct Validated<V: Validator> {
    public let value: V.InputType

    public init(_ value: V.InputType, by validator: V) throws {
        try self.value = value.tested(by: validator)
    }
}

extension Validated where V: ValidationSuite {
    public init(_ value: V.InputType, by suite: V.Type = V.self) throws {
        try self.value = value.tested(by: suite)
    }
}
