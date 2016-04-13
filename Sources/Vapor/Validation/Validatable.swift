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
    public func tested(@noescape by tester: (input: Self) throws -> Void) throws -> Self {
        try tester(input: self)
        return self
    }

    public func tested<V: Validator where V.InputType == Self>(by tester: V) throws -> Self {
        return try tested(by: tester.validate)
    }

    public func tested<S: ValidationSuite where S.InputType == Self>(by tester: S.Type) throws -> Self {
        return try tested(by: tester.validate)
    }

}

extension Optional where Wrapped: Validatable {
    public func tested(@noescape by tester: (input: Wrapped) throws -> Void) throws -> Wrapped {
        guard case .some(let value) = self else { throw Failure<Wrapped>(input: nil) }
        return try value.tested(by: tester)
    }

    public func tested<V: Validator where V.InputType == Wrapped>(by validator: V) throws -> Wrapped {
        return try tested(by: validator.validate)
    }

    public func tested<S: ValidationSuite where S.InputType == Wrapped>(by suite: S.Type) throws -> Wrapped {
        return try tested(by: suite.validate)
    }
}

// MARK: Passing

extension Validatable {
    public func passes(@noescape tester: (input: Self) throws -> Void) -> Bool {
        do {
            try tester(input: self)
            return true
        } catch {
            return false
        }
    }

    public func passes<V: Validator where V.InputType == Self>(tester: V) -> Bool {
        return passes(tester.validate)
    }

    public func passes<S: ValidationSuite where S.InputType == Self>(tester: S.Type) -> Bool {
        return passes(tester.validate)
    }
}

extension Optional where Wrapped: Validatable {
    public func passes(@noescape tester: (input: Wrapped) throws -> Void) -> Bool {
        guard case .some(let value) = self else { return false }
        return value.passes(tester)
    }

    public func passes<V: Validator where V.InputType == Wrapped>(validator: V) -> Bool {
        return passes(validator.validate)
    }

    public func passes<S: ValidationSuite where S.InputType == Wrapped>(by suite: S.Type) -> Bool {
        return passes(suite.validate)
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
        guard case .some(let value) = self else { throw Failure<Wrapped>(input: nil) }
        return try Validated<V>(value, by: validator)
    }
    public func validated<S: ValidationSuite where S.InputType == Wrapped>(by type: S.Type = S.self) throws -> Validated<S> {
        guard case .some(let value) = self else { throw Failure<Wrapped>(input: nil) }
        return try Validated<S>(value, by: S.self)
    }
}
