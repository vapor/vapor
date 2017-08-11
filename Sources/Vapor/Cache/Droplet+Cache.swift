import Caches

extension Droplet {
    /// Store and retreive key:value
    /// pair information.
    public func cache() throws -> CacheProtocol {
        return try make()
    }
}
