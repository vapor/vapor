extension Node {
    /**
        Transform and validate a node

        - parameter suite: suite to validate with

        - throws: an error if one occurs

        - returns: a validated object
    */
    public func validated<
        T: ValidationSuite
        where T.InputType: NodeInitializable>(by suite: T.Type = T.self)
        throws -> Valid<T> {
            let value = try T.InputType.make(with: self)
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
        where T.InputType: NodeInitializable>(by validator: T)
        throws -> Valid<T> {
            let value = try T.InputType.make(with: self)
            return try value.validated(by: validator)
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

extension Extractable where Wrapped == Node {

    /**
        transform and validate an extractable encapsulating a node.

        - parameter suite: suite to validate with

        - throws: an error if one occurs

        - returns: a validated object
     */
    public func validated<
        V: ValidationSuite
        where V.InputType: NodeInitializable>(by suite: V.Type = V.self)
        throws -> Valid<V> {
            guard let wrapped = extract() else {
                throw ValidationError(suite, input: nil)
            }
            let value = try V.InputType.make(with: wrapped)
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
        where V.InputType: NodeInitializable>(by validator: V)
        throws -> Valid<V> {
            guard let wrapped = extract() else {
                throw ValidationError(validator, input: nil)
            }
            let value = try V.InputType.make(with: wrapped)
            return try value.validated(by: validator)
    }
}

extension Extractable where Wrapped == [Node] {

    /**
        transforms and validates an array of nodes

        - parameter suite: suite to validate with

        - throws: an error if one occurs

        - returns: validated value if possible
     */
    public func validated<
        V: ValidationSuite,
        I: NodeInitializable
        where V.InputType == [I]>(by suite: V.Type = V.self)
        throws -> Valid<V> {
            guard let wrapped = extract() else {
                throw ValidationError(suite, input: nil)
            }

            return try wrapped
                .map(I.make)
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
        I: NodeInitializable
        where V.InputType == [I]>(by validator: V)
        throws -> Valid<V> {
            guard let wrapped = extract() else {
                throw ValidationError(validator, input: nil)
            }

            return try wrapped
                .map(I.make)
                .validated(by: validator)
    }
}

extension Extractable where Wrapped == [String : Node] {

    /**
        transforms and validates a dictionary w type [String : Node]

        - parameter suite: suite to validate with

        - throws: an error if one occurs

        - returns: validated value if possible
     */
    public func validated<
        V: ValidationSuite,
        I: NodeInitializable
        where V.InputType == [String : I]>(by suite: V.Type = V.self)
        throws -> Valid<V> {
            guard let wrapped = extract() else {
                throw ValidationError(suite, input: nil)
            }

            var mapped: [String : I] = [:]
            try wrapped.forEach { k, v in
                mapped[k] = try I.make(with: v)
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
        I: NodeInitializable
        where V.InputType == [String : I]>(by validator: V)
        throws -> Valid<V> {
            guard let wrapped = extract() else {
                throw ValidationError(validator, input: nil)
            }

            var mapped: [String : I] = [:]
            try wrapped.forEach { k, v in
                mapped[k] = try I.make(with: v)
            }

            return try mapped.validated(by: validator)
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
