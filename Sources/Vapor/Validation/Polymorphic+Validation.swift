import protocol Core.Extractable

extension Polymorphic {
    /**
        Transform and validate a node

        - parameter suite: suite to validate with

        - throws: an error if one occurs

        - returns: a validated object
    */
    public func validated<
        T: ValidationSuite
        where T.InputType: PolymorphicInitializable>(by suite: T.Type = T.self
    ) throws -> Valid<T> {
        let value = try T.InputType.init(polymorphic: self)
        return try value.validated(by: suite)
    }

    /**
        Transform and validate a node

        - parameter validator: validator to validate with

        - throws: an error if one occurs

        - returns: a validated object
    */
    public func validated<
        T: Validator
        where T.InputType: PolymorphicInitializable>(by validator: T
    ) throws -> Valid<T> {
        let value = try T.InputType.init(polymorphic: self)
        return try value.validated(by: validator)
    }
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
        where V.InputType: PolymorphicInitializable>(by suite: V.Type = V.self
    ) throws -> Valid<V> {
        guard let wrapped = extract() else {
            throw ValidationError(suite, input: nil)
        }

        let value = try V.InputType.init(polymorphic: wrapped)
        return try value.validated(by: suite)
    }

    /**
        transform and validate an extractable encapsulating a node.

        - parameter validator: validator to validate with

        - throws: an error if one occurs

        - returns: a validated object
     */
    public func validated<
        V: Validator
        where V.InputType: PolymorphicInitializable>(by validator: V
    ) throws -> Valid<V> {
        guard let wrapped = extract() else {
            throw ValidationError(validator, input: nil)
        }

        let value = try V.InputType.init(polymorphic: wrapped)
        return try value.validated(by: validator)
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
        where V.InputType == [I]>(by suite: V.Type = V.self
    ) throws -> Valid<V> {
        guard let wrapped = extract() else {
            throw ValidationError(suite, input: nil)
        }

        return try wrapped
            .map(I.init)
            .validated(by: suite)
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
        where V.InputType == [I]>(by validator: V
    ) throws -> Valid<V> {
        guard let wrapped = extract() else {
            throw ValidationError(validator, input: nil)
        }

        return try wrapped
            .map(I.init)
            .validated(by: validator)
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
        where V.InputType == [String : I]>(by suite: V.Type = V.self
    ) throws -> Valid<V> {
        guard let wrapped = extract() else {
            throw ValidationError(suite, input: nil)
        }

        var mapped: [String : I] = [:]

        try wrapped.forEach { key, val in
            mapped[key] = try I.init(polymorphic: val)
        }

        return try mapped.validated(by: suite)
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
        where V.InputType == [String : I]>(by validator: V
    ) throws -> Valid<V> {
        guard let wrapped = extract() else {
            throw ValidationError(validator, input: nil)
        }

        var mapped: [String : I] = [:]

        try wrapped.forEach { key, val in
            mapped[key] = try I.init(polymorphic: val)
        }

        return try mapped.validated(by: validator)
    }
}
