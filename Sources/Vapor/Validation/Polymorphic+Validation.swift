extension Polymorphic {
    /**
        Transform and validate a node

        - parameter suite: suite to validate with

        - throws: an error if one occurs

        - returns: a validated object
    */
    public func validated<
        T: ValidationSuite>(by suite: T.Type = T.self
        ) throws -> Valid<T>
        where T.InputType: PolymorphicInitializable {
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
        T: Validator>(by validator: T
        ) throws -> Valid<T>
        where T.InputType: PolymorphicInitializable {
        let value = try T.InputType.init(polymorphic: self)
        return try value.validated(by: validator)
    }
}
