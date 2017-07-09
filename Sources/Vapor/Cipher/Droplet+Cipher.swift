extension Droplet {
    /// Provides access to the underlying
    /// `CipherProtocol` for encrypting and
    /// decrypting data.
    public func cipher() throws -> CipherProtocol {
        return try make()
    }
}
