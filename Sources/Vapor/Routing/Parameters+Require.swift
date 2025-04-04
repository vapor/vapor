import RoutingKit

extension Parameters {
    /// Grabs the named parameter from the parameter bag.
    /// If the parameter does not exist, `Abort(.internalServerError)` is thrown.
    /// If the parameter value cannot be converted to `String`, `Abort(.unprocessableContent)` is thrown.
    ///
    /// - parameters:
    ///     - name: The name of the parameter.
    public func require(_ name: String) throws -> String {
        return try self.require(name, as: String.self)
    }

    /// Grabs the named parameter from the parameter bag, casting it to a `LosslessStringConvertible` type.
    /// If the parameter does not exist, `Abort(.internalServerError)` is thrown.
    /// If the parameter value cannot be converted to the required type, `Abort(.unprocessableContent)` is thrown.
    ///
    /// - parameters:
    ///     - name: The name of the parameter.
    ///     - type: The required parameter value type.
    public func require<T>(_ name: String, as type: T.Type = T.self) throws -> T
        where T: LosslessStringConvertible
    {
        guard let stringValue: String = get(name) else {
            self.logger.debug("The parameter \(name) does not exist")
            throw Abort(.internalServerError, reason: "The parameter provided does not exist")
        }

        guard let value = T.init(stringValue) else {
            self.logger.debug("The parameter \(stringValue) could not be converted to \(T.Type.self)")
            throw Abort(.unprocessableContent, reason: "The parameter value could not be converted to the required type")
        }

        return value
    }
}
