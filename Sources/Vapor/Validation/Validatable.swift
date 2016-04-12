public protocol Validatable {}

// MARK: Conformance

extension String: Validatable {}

extension Set: Validatable {}
extension Array: Validatable {}
extension Dictionary: Validatable {}

extension Int: Validatable {}
extension Int8: Validatable {}
extension Int16: Validatable {}
extension Int32: Validatable {}
extension Int64: Validatable {}

extension UInt: Validatable {}
extension UInt8: Validatable {}
extension UInt16: Validatable {}
extension UInt32: Validatable {}
extension UInt64: Validatable {}

extension Float: Validatable {}
extension Double: Validatable {}

// MARK: Testing

extension Validatable {
    public func tested(@noescape by tester: (input: Self) throws -> Bool) throws -> Self {
        guard try tester(input: self) else { throw "up" }
        return self
    }

    public func tested<V: Validator where V.InputType == Self>(by tester: V) throws -> Self {
        return try tested(by: tester.test)
    }

    public func tested<S: ValidationSuite where S.InputType == Self>(by tester: S.Type) throws -> Self {
        return try tested(by: tester.test)
    }

}

extension Optional where Wrapped: Validatable {
    public func tested(@noescape by tester: (input: Wrapped) throws -> Bool) throws -> Wrapped {
        guard case .some(let value) = self else { throw "error" }
        return try value.tested(by: tester)
    }

    public func tested<V: Validator where V.InputType == Wrapped>(by validator: V) throws -> Wrapped {
        return try tested(by: validator.test)
    }

    public func tested<S: ValidationSuite where S.InputType == Wrapped>(by suite: S.Type) throws -> Wrapped {
        return try tested(by: suite.test)
    }
}

// MARK: Validation

extension Validatable {
    public func validated<V: Validator where V.InputType == Self>(by validator: V) throws -> Validated<V> {
        return try Validated<V>(self, by: validator)
    }
    public func validated<S: ValidationSuite where S.InputType == Self>(by type: S.Type = S.self) throws -> Validated<S> {
        return try Validated<S>(self, by: S.self)
    }
}

extension Optional where Wrapped: Validatable {
    public func validated<V: Validator where V.InputType == Wrapped>(by validator: V) throws -> Validated<V> {
        guard case .some(let value) = self else { throw "error" }
        return try Validated<V>(value, by: validator)
    }
    public func validated<S: ValidationSuite where S.InputType == Wrapped>(by type: S.Type = S.self) throws -> Validated<S> {
        guard case .some(let value) = self else { throw "error" }
        return try Validated<S>(value, by: S.self)
    }
}
