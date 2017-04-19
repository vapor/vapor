extension Config {
    /// Adds a configurable Cipher instance.
    public mutating func addConfigurable<
        Cipher: CipherProtocol
    >(cipher: Cipher, name: String) {
        customAddConfigurable(instance: cipher, unique: "cipher", name: name)
    }
    
    /// Adds a configurable Cipher class.
    public mutating func addConfigurable<
        Cipher: CipherProtocol & ConfigInitializable
    >(cipher: Cipher.Type, name: String) {
        customAddConfigurable(class: Cipher.self, unique: "cipher", name: name)
    }
    
    /// Resolves the configured Cipher.
    public mutating func resolveCipher() throws -> CipherProtocol {
        return try customResolve(
            unique: "cipher",
            file: "droplet",
            keyPath: ["cipher"],
            as: CipherProtocol.self
        ) { config in
            return CryptoCipher(
                method: .aes256(.cbc),
                defaultKey: Bytes(repeating: 0, count: 16)
            )
        }
    }
}
