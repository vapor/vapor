extension String: ErrorProtocol {}

/*
 Possible Naming Conventions

 validated passes Tester -> Verified<T: Tester>
 validated passes TestSuite -> Verified<T: TestSuite>

 tested with (Self -> Bool) -> Self
 tested with Tester -> Self
 tested with TestSuite -> Self
 */

public protocol Validatable {}

// MARK: Validated Returns

extension Validatable {
    // MARK: Designated
    public func tested(@noescape passes tester: (input: Self) throws -> Bool) throws -> Self {
        guard try tester(input: self) else { throw "up" }
        return self
    }
}

// MARK: Validators

public protocol Validator {
    associatedtype InputType: Validatable
    func test(input value: InputType) throws -> Bool
}


extension Validatable {
    public func tested<T: Validator where T.InputType == Self>(passes tester: T) throws -> Self {
        return try tested(passes: tester.test)
    }

}

extension Optional where Wrapped: Validatable {
    public func tested(passes tester: (input: Wrapped) throws -> Bool) throws -> Wrapped {
        guard case .some(let value) = self else { throw "error" }
        return try value.tested(passes: tester)
    }

    public func tested<V: Validator where V.InputType == Wrapped>(passes validator: V) throws -> Wrapped {
        return try tested(passes: validator.test)
    }

    // TODO: Add validated(by: ` for optional versions
}

// MARK: Valiidation on Input

extension Validatable {
    public func validated<V: Validator where V.InputType == Self>(by validator: V) throws -> Validated<V> {
        return try Validated<V>(self, with: validator)
    }
    public func validated<S: ValidationSuite where S.InputType == Self>(by type: S.Type = S.self) throws -> Validated<S> {
        return try Validated<S>(self, with: S.self)
    }
}

extension Validatable {
    public func tested(passes collection: [(input: Self) throws -> Bool]) throws -> Self {
        for test in collection where !(try test(input: self)) {
            throw "up"
        }
        return self
    }

    public func tested<T: ValidationSuite where T.InputType == Self>(passes suite: T.Type) throws -> Self {
        guard try T.test(input: self) else { throw "up" }
        return self
    }
}


// MARK: Conformance

extension String: Validatable {}
extension Int: Validatable {}
extension Array: Validatable {}
extension Dictionary: Validatable {}

public protocol ValidationSuite: Validator {
    associatedtype InputType: Validatable
    static func test(input value: InputType) throws -> Bool
}

extension ValidationSuite {
    public func test(input value: InputType) throws -> Bool {
        return try self.dynamicType.test(input: value)
    }
}

// MARK: Validated

public struct Validated<V: Validator> {
    public let value: V.InputType

    public init(_ value: V.InputType, with validator: V) throws {
        try self.value = value.tested(passes: validator)
    }
}

extension Validated where V: ValidationSuite {
    public init(_ value: V.InputType, with suite: V.Type = V.self) throws {
        try self.value = value.tested(passes: suite)
    }
}

