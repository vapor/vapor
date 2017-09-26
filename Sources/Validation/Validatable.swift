/// A client request that is validatable using a validator
public protocol Validatable {
    /// Validates the current entity to a validator
    ///
    /// Does not throw an error when validation fails
    ///
    /// - throws: When a validation step failed, like fetching entities from the database
    func validate(loggingTo validator: Validator) throws
}

extension Validatable {
    /// Asserts the successful validation of the input
    ///
    /// - throws: An error when validation fails at one or more points
    public func assertValid() throws {
        let log = Validator()
        
        try self.validate(loggingTo: log)
        
        guard log.errors.count == 0 else {
            throw log
        }
    }
}
