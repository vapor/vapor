import Cache

extension Droplet {
    /// Store and retreive key:value
    /// pair information.
    public func cache() throws -> Cache {
        return try make()
    }
}
