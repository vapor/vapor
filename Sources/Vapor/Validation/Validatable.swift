/**
    Validatable struct is used to indicate that a value can be validated.
    It requires no special attributes or conformance.

    It's purpose is largely based on convenient code share and by
    conforming an object inherits a great deal of syntax to more 
    conveniently work with validators.

    Naming Conventions

    - tested throws -> Self
    - passed -> Bool
    - validated throws -> Valid<Validator>
*/
public protocol Validatable {}

// MARK: Conformance

extension String: Validatable {}

extension Set: Validatable {}
extension Array: Validatable {}
extension Dictionary: Validatable {}

extension Bool: Validatable {}

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
    /**
        Test whether or not the caller passes the given tester

        - parameter tester: a closure that might potentially fail testing

        - rethrows: the encompassed error of the tester

        - returns: self if passed tester
    */
    public func tested(
        by tester: @noescape (input: Self) throws -> Void)
        rethrows -> Self {
            try tester(input: self)
            return self
    }

    /**
        Test whether or not the caller passes the given Validator

        - parameter validator: the validator to validate with

        - throws: an error if test fails

        - returns: self if passed validator
    */
    public func tested<
        V: Validator
        where V.InputType == Self>(by validator: V)
        throws -> Self {
            return try tested(by: validator.validate)
    }

    /**
        Test whether or not the caller passes the given ValidationSuite

        - parameter suite: the suite to validate with

        - throws: an error if test fails

        - returns: self if passed suite
    */
    public func tested<
        S: ValidationSuite
        where S.InputType == Self>(by suite: S.Type)
        throws -> Self {
            return try tested(by: suite.validate)
    }
}

extension Optional where Wrapped: Validatable {
    /**
        Test whether or not the caller passes the given Validator
        Fails if `== .None`

        - parameter validator: the validator to validate with

        - throws: an error if test fails

        - returns: self if passed validator
    */
    public func tested<
        V: Validator
        where V.InputType == Wrapped>(by validator: V)
        throws -> Wrapped {
            guard case .some(let value) = self else {
                throw ValidationError(validator, input: nil)
            }
            return try value.tested(by: validator)
    }

    /**
        Test whether or not the caller passes the given ValidationSuite
        Fails if `== .None`

        - parameter suite: the suite to validate with

        - throws: an error if test fails

        - returns: self if passed suite
    */
    public func tested<
        S: ValidationSuite
        where S.InputType == Wrapped>(by suite: S.Type)
        throws -> Wrapped {
            guard case .some(let value) = self else {
                throw ValidationError(suite, input: nil)
            }
            return try value.tested(by: suite)
    }
}

// MARK: Passing

extension Validatable {
    /**
        Test whether or not the caller passes the given tester

        - parameter tester: the tester to evaluate with

        - returns: whether or not the caller passed
    */
    public func passes(_ tester: @noescape (input: Self) throws -> Void) -> Bool {
        do {
            try tester(input: self)
            return true
        } catch {
            return false
        }
    }

    /**
        Test whether or not the caller passes the given Validator

        - parameter validator: the validator to evaluate with

        - returns: whether or not the caller passed
    */
    public func passes<V: Validator where V.InputType == Self>(_ validator: V) -> Bool {
        return passes(validator.validate)
    }

    /**
        Test whether or not the caller passes the given ValidationSuite

        - parameter suite: the validation suite to evaluate with

        - returns: whether or not the caller passed
    */
    public func passes<S: ValidationSuite where S.InputType == Self>(_ suite: S.Type) -> Bool {
        return passes(suite.validate)
    }
}

extension Optional where Wrapped: Validatable {
    /**
        Test whether or not the caller passes the given tester
        Fails if `== .None`

        - parameter tester: the tester to evaluate with

        - returns: whether or not the caller passed
    */
    public func passes(_ tester: @noescape (input: Wrapped) throws -> Void) -> Bool {
        guard case .some(let value) = self else { return false }
        return value.passes(tester)
    }

    /**
        Test whether or not the caller passes the given Validator
        Fails if `== .None`

        - parameter validator: the validator to evaluate with

        - returns: whether or not the caller passed
    */
    public func passes<V: Validator where V.InputType == Wrapped>(_ validator: V) -> Bool {
        return passes(validator.validate)
    }

    /**
        Test whether or not the caller passes the given ValidationSuite
        Fails if `== .None`

        - parameter suite: the validation suite to evaluate with

        - returns: whether or not the caller passed
    */
    public func passes<S: ValidationSuite where S.InputType == Wrapped>(_ suite: S.Type) -> Bool {
        return passes(suite.validate)
    }
}

// MARK: Validation

extension Validatable {
    /**
        Validates a given value if possible

        - parameter validator: the validator to use in evaluating the value

        - throws: an error if validation fails

        - returns: a Valid<V> protecting a successfully validated value
    */
    public func validated<
        V: Validator
        where V.InputType == Self>(by validator: V)
        throws -> Valid<V> {
            return try Valid<V>(self, by: validator)
    }

    /**
        Validates a given value if possible

        - parameter suite: the validation suite to use in evaluating the value

        - throws: an error if validation fails

        - returns: a Valid<V> protecting a successfully validated value
    */
    public func validated<
        S: ValidationSuite
        where S.InputType == Self>(by suite: S.Type = S.self)
        throws -> Valid<S> {
            return try Valid<S>(self, by: suite)
    }
}

extension Optional where Wrapped: Validatable {
    /**
        Validates a given value if possible
        Fails if `== .None`

        - parameter validator: the validator to use in evaluating the value

        - throws: an error if validation fails

        - returns: a Valid<V> protecting a successfully validated value
    */
    public func validated<
        V: Validator
        where V.InputType == Wrapped>(by validator: V)
        throws -> Valid<V> {
            guard case .some(let value) = self else {
                throw ValidationError(validator, input: nil)
            }
            return try Valid<V>(value, by: validator)
    }

    /**
        Validates a given value if possible
        Fails if `== .None`

        - parameter suite: the validation suite to use in evaluating the value

        - throws: an error if validation fails

        - returns: a Valid<V> protecting a successfully validated value
    */
    public func validated<
        S: ValidationSuite
        where S.InputType == Wrapped>(by suite: S.Type = S.self)
        throws -> Valid<S> {
            guard case .some(let value) = self else {
                throw ValidationError(suite, input: nil)
            }
            return try Valid<S>(value, by: suite)
    }
}
