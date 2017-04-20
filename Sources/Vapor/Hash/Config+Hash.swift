extension Config {
    /// Adds a configurable Hash.
    public func addConfigurable<
        Hash: HashProtocol
    >(hash: @escaping Config.Lazy<Hash>, name: String) {
        customAddConfigurable(closure: hash, unique: "hash", name: name)
    }
    
    /// Resolves the configured Hash.
    public func resolveHash() throws -> HashProtocol {
        return try customResolve(
            unique: "hash",
            file: "droplet",
            keyPath: ["hash"],
            as: HashProtocol.self
        ) { config in
            return CryptoHasher(hash: .sha1, encoding: .hex)
        }
    }
}
