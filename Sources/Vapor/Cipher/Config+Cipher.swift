extension Config {
    /// Adds a configurable Cipher.
    public func addConfigurable<
        Cipher: CipherProtocol
    >(cipher: @escaping Config.Lazy<Cipher>, name: String) {
        customAddConfigurable(closure: cipher, unique: "cipher", name: name)
    }
    
    /// Resolves the configured Cipher.
    public func resolveCipher() throws -> CipherProtocol {
        return try customResolve(
            unique: "cipher",
            file: "droplet",
            keyPath: ["cipher"],
            as: CipherProtocol.self
        ) { config in
            let log = try config.resolveLog()

            let message = "The default cipher should be replaced before using in production."
            if config.environment == .production {
                log.error(message)
            } else {
                log.warning(message)
            }

            return try CryptoCipher(
                method: .aes256(.cbc),
                key: Bytes(repeating: 0, count: 32),
                encoding: .base64
            )
        }
    }
}
