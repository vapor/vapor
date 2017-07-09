extension Droplet {
    /// Expose to end users to customize driver
    /// Make outgoing requests
    public func client() throws -> ClientFactoryProtocol {
        return try make()
    }
}
