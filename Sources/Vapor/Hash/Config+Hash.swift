extension Config {
    /// Adds a configurable Hash instance.
    public func addConfigurable<
        Hash: HashProtocol
    >(hash: Hash, name: String) {
        customAddConfigurable(instance: hash, unique: "hash", name: name)
    }
    
    /// Adds a configurable Hash class.
    public func addConfigurable<
        Hash: HashProtocol & ConfigInitializable
    >(hash: Hash.Type, name: String) {
        customAddConfigurable(class: Hash.self, unique: "hash", name: name)
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
