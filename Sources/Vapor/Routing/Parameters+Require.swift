public extension Parameters {
    /// Grabs the named parameter from the parameter bag.
    /// An `Abort(.unprocessableEntity)` error is thrown if the parameter does not exist.
    func require(_ name: String, or error: Error = Abort(.unprocessableEntity)) throws -> String {
        guard let value = get(name) else {
            throw error
        }

        return value
    }

    /// Grabs the named parameter from the parameter bag, casting it to
    /// a `LosslessStringConvertible` type.
    /// An `Abort(.unprocessableEntity)` error is thrown if the parameter does not exist.
    func require<T>(_ name: String, as type: T.Type = T.self, or error: Error = Abort(.unprocessableEntity)) throws -> T
        where T: LosslessStringConvertible
    {
        guard let value = try T.init(require(name, or: error)) else {
            throw error
        }

        return value
    }
}
