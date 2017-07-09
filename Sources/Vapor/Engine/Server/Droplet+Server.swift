extension Droplet {
    /// The server that will accept requesting
    /// connections and return the desired
    /// response.
    public func server() throws -> ServerFactoryProtocol {
        return try make()
    }
}
