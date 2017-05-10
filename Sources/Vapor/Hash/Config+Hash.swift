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
            let log = try config.resolveLog()

            let message = "The default hash should be replaced before using in production."
            if config.environment == .production {
                log.error(message)
            } else {
                log.warning(message)
            }

            return CryptoHasher(hash: .sha1, encoding: .hex)
        }
    }
}
