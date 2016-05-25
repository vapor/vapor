extension Polymorphic {
    /**
        Transform and validate a node

        - parameter suite: suite to validate with

        - throws: an error if one occurs

        - returns: a validated object
    */
    public func validated<
        T: ValidationSuite
        where T.InputType: PolymorphicInitializable>(by suite: T.Type = T.self)
        throws -> Valid<T>
    {
        do {
            let value = try T.InputType.init(polymorphic: self)
            return try value.validated(by: suite)
        } catch PolymorphicInitializableError.couldNotInitialize {
            throw ValidationError(suite, input: nil, message: "Validating \(suite) failed for input '\(self)'")
        }
    }

    /**
        Transform and validate a node

        - parameter validator: validator to validate with

        - throws: an error if one occurs

        - returns: a validated object
    */
    public func validated<
        T: Validator
        where T.InputType: PolymorphicInitializable>(by validator: T)
        throws -> Valid<T>
    {
        do {
            let value = try T.InputType.init(polymorphic: self)
            return try value.validated(by: validator)
        } catch PolymorphicInitializableError.couldNotInitialize {
            throw ValidationError(validator, input: nil, message: "Validating \(validator) failed for input '\(self)'")
        }
    }
}

/**
    We can't generically extend optionals based on their contents being protocols concretely,
    ie: where Wrapped == SomeProtocol
 
    This allows us to do so because extending protocol can use concrete generic constraints
*/
public protocol Extractable {

    /**
        The underlying type
    */
    associatedtype Wrapped

    /**
        Access the underlying value

        - returns: the underlying value if exists
    */
    func extract() -> Wrapped?
}

extension Extractable where Wrapped == Polymorphic {

    /**
        transform and validate an extractable encapsulating a node.

        - parameter suite: suite to validate with

        - throws: an error if one occurs

        - returns: a validated object
     */
    public func validated<
        V: ValidationSuite
        where V.InputType: PolymorphicInitializable>(by suite: V.Type = V.self)
        throws -> Valid<V>
    {
        guard let wrapped = extract() else {
            throw ValidationError(suite, input: nil)
        }

        do {
            let value = try V.InputType.init(polymorphic: wrapped)
            return try value.validated(by: suite)
        } catch PolymorphicInitializableError.couldNotInitialize {
            throw ValidationError(suite, input: nil, message: "Validating \(suite) failed for input '\(wrapped)'")
        }
    }

    /**
        transform and validate an extractable encapsulating a node.

        - parameter validator: validator to validate with

        - throws: an error if one occurs

        - returns: a validated object
     */
    public func validated<
        V: Validator
        where V.InputType: PolymorphicInitializable>(by validator: V)
        throws -> Valid<V>
    {
        guard let wrapped = extract() else {
            throw ValidationError(validator, input: nil)
        }

        do {
            let value = try V.InputType.init(polymorphic: wrapped)
            return try value.validated(by: validator)
        } catch PolymorphicInitializableError.couldNotInitialize {
            throw ValidationError(validator, input: nil, message: "Validating \(validator) failed for input '\(wrapped)'")
        }
    }
}

extension Extractable where Wrapped == [Polymorphic] {

    /**
        transforms and validates an array of nodes

        - parameter suite: suite to validate with

        - throws: an error if one occurs

        - returns: validated value if possible
     */
    public func validated<
        V: ValidationSuite,
        I: PolymorphicInitializable
        where V.InputType == [I]>(by suite: V.Type = V.self)
        throws -> Valid<V>
    {
        guard let wrapped = extract() else {
            throw ValidationError(suite, input: nil)
        }

        do {
            return try wrapped
                .map(I.init)
                .validated(by: suite)
        } catch PolymorphicInitializableError.couldNotInitialize {
            throw ValidationError(suite, input: nil, message: "Validating \(suite) failed for input '\(wrapped)'")
        }
    }

    /**
        transforms and validates an array of nodes

        - parameter validator: validator to validate with

        - throws: an error if one occurs

        - returns: validated value if possible
     */
    public func validated<
        V: Validator,
        I: PolymorphicInitializable
        where V.InputType == [I]>(by validator: V)
        throws -> Valid<V>
    {
        guard let wrapped = extract() else {
            throw ValidationError(validator, input: nil)
        }

        do {
            return try wrapped
                .map(I.init)
                .validated(by: validator)
        } catch PolymorphicInitializableError.couldNotInitialize {
            throw ValidationError(validator, input: nil, message: "Validating \(validator) failed for input '\(wrapped)'")
        }
    }
}

extension Extractable where Wrapped == [String : Polymorphic] {

    /**
        transforms and validates a dictionary w type [String : Node]

        - parameter suite: suite to validate with

        - throws: an error if one occurs

        - returns: validated value if possible
     */
    public func validated<
        V: ValidationSuite,
        I: PolymorphicInitializable
        where V.InputType == [String : I]>(by suite: V.Type = V.self)
        throws -> Valid<V>
    {
        guard let wrapped = extract() else {
            throw ValidationError(suite, input: nil)
        }

        var mapped: [String : I] = [:]

        do {
            try wrapped.forEach { k, v in
                mapped[k] = try I.init(polymorphic: v)
            }

            return try mapped.validated(by: suite)
        } catch PolymorphicInitializableError.couldNotInitialize {
            throw ValidationError(suite, input: nil, message: "Validating \(suite) failed for input '\(wrapped)'")
        }
    }

    /**
        transforms and validates a dictionary w type [String : Node]

        - parameter validator: validator to validate with

        - throws: an error if one occurs

        - returns: validated value if possible
     */
    public func validated<
        V: Validator,
        I: PolymorphicInitializable
        where V.InputType == [String : I]>(by validator: V)
        throws -> Valid<V>
    {
        guard let wrapped = extract() else {
            throw ValidationError(validator, input: nil)
        }

        var mapped: [String : I] = [:]

        do {
            try wrapped.forEach { k, v in
                mapped[k] = try I.init(polymorphic: v)
            }

            return try mapped.validated(by: validator)
        } catch PolymorphicInitializableError.couldNotInitialize {
            throw ValidationError(validator, input: nil, message: "Validating \(validator) failed for input '\(wrapped)'")
        }
    }
}

extension Optional: Extractable {
    /**
        Extract the underlying value if possible

        - returns: a value if possible
     */
    public func extract() -> Wrapped? {
        return self
    }
}
