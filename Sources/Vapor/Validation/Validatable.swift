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
//public protocol _Validatable {}

// MARK: Conformance

extension String: _Validatable {}

extension Set: _Validatable {}
extension Array: _Validatable {}
extension Dictionary: _Validatable {}

extension Bool: _Validatable {}

extension Int: _Validatable {}
extension Int8: _Validatable {}
extension Int16: _Validatable {}
extension Int32: _Validatable {}
extension Int64: _Validatable {}

extension UInt: _Validatable {}
extension UInt8: _Validatable {}
extension UInt16: _Validatable {}
extension UInt32: _Validatable {}
extension UInt64: _Validatable {}

extension Float: _Validatable {}
extension Double: _Validatable {}


// MARK: Testing

//extension Validatable {
//    /**
//        Test whether or not the caller passes the given tester
//
//        - parameter tester: a closure that might potentially fail testing
//
//        - rethrows: the encompassed error of the tester
//
//        - returns: self if passed tester
//    */
//    public func tested(
//        by tester: (Self) throws -> Void)
//        rethrows -> Self {
//            try tester(self)
//            return self
//    }
//
//    /**
//        Test whether or not the caller passes the given Validator
//
//        - parameter validator: the validator to validate with
//
//        - throws: an error if test fails
//
//        - returns: self if passed validator
//    */
//    public func tested<V: Validator>(by validator: V)
//        throws -> Self
//        where V.InputType == Self {
//            return try tested(by: validator.validate)
//    }
//
//    /**
//        Test whether or not the caller passes the given ValidationSuite
//
//        - parameter suite: the suite to validate with
//
//        - throws: an error if test fails
//
//        - returns: self if passed suite
//    */
//    public func tested<
//        S: ValidationSuite>(by suite: S.Type)
//        throws -> Self
//        where S.InputType == Self {
//            return try tested(by: suite.validate)
//    }
//}
//
//// MARK: Passing
//
//extension Validatable {
//    /**
//        Test whether or not the caller passes the given tester
//
//        - parameter tester: the tester to evaluate with
//
//        - returns: whether or not the caller passed
//    */
//    public func passes(_ tester: (Self) throws -> Void) -> Bool {
//        do {
//            try tester(self)
//            return true
//        } catch {
//            return false
//        }
//    }
//
//    /**
//        Test whether or not the caller passes the given Validator
//
//        - parameter validator: the validator to evaluate with
//
//        - returns: whether or not the caller passed
//    */
//    public func passes<V: Validator>(_ validator: V) -> Bool where V.InputType == Self {
//        return passes(validator.validate)
//    }
//
//    /**
//        Test whether or not the caller passes the given ValidationSuite
//
//        - parameter suite: the validation suite to evaluate with
//
//        - returns: whether or not the caller passed
//    */
//    public func passes<S: ValidationSuite>(_ suite: S.Type) -> Bool where S.InputType == Self {
//        return passes(suite.validate)
//    }
//}
//
//// MARK: Validation
//
//extension Validatable {
//    /**
//        Validates a given value if possible
//
//        - parameter validator: the validator to use in evaluating the value
//
//        - throws: an error if validation fails
//
//        - returns: a Valid<V> protecting a successfully validated value
//    */
//    public func validated<
//        V: Validator>(by validator: V)
//        throws -> Valid<V>
//        where V.InputType == Self {
//            return try Valid<V>(self, by: validator)
//    }
//
//    /**
//        Validates a given value if possible
//
//        - parameter suite: the validation suite to use in evaluating the value
//
//        - throws: an error if validation fails
//
//        - returns: a Valid<V> protecting a successfully validated value
//    */
//    public func validated<
//        S: ValidationSuite>(by suite: S.Type = S.self)
//        throws -> Valid<S>
//        where S.InputType == Self {
//            return try Valid<S>(self, by: suite)
//    }
//}
