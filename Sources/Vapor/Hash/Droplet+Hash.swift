extension Droplet {
    /// Provides access to the underlying
    /// `HashProtocol` for hashing data.
    public func hash() throws -> HashProtocol {
        return try make()
    }
}
