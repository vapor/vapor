extension Parameters {
    /// Grabs the named parameter from the parameter bag.
    /// If the parameter does not exist, `Abort(.internalServerError)` is thrown.
    /// If the parameter value cannot be converted to `String`, `Abort(.unprocessableEntity)` is thrown.
    ///
    /// - parameters:
    ///     - name: The name of the parameter.
    public func require(_ name: String) throws -> String {
        return try self.require(name, as: String.self)
    }

    /// Grabs the named parameter from the parameter bag, casting it to a `LosslessStringConvertible` type.
    /// If the parameter does not exist, `Abort(.internalServerError)` is thrown.
    /// If the parameter value cannot be converted to the generic type, `Abort(.unprocessableEntity)` is thrown.
    ///
    /// - parameters:
    ///     - name: The name of the parameter.
    public func require<T>(_ name: String, as type: T.Type = T.self) throws -> T
        where T: LosslessStringConvertible
    {
        guard let stringValue: String = get(name) else {
            throw Abort(.internalServerError)
        }

        guard let value = T.init(stringValue) else {
            throw Abort(.unprocessableEntity)
        }

        return value
    }
}
