extension Config {
    /// Adds a configurable Hash instance.
    public mutating func addConfigurable<
        Hash: HashProtocol
    >(hash: Hash, name: String) {
        addConfigurable(instance: hash, unique: "hash", name: name)
    }
    
    /// Adds a configurable Hash class.
    public mutating func addConfigurable<
        Hash: HashProtocol & ConfigInitializable
    >(hash: Hash.Type, name: String) {
        addConfigurable(class: Hash.self, unique: "hash", name: name)
    }
    
    /// Resolves the configured Hash.
    public func resolveHash() throws -> HashProtocol {
        return try resolve(
            unique: "hash",
            file: "droplet",
            keyPath: ["hash"],
            as: HashProtocol.self,
            default: CryptoHasher.init
        )
    }
}
