extension Config {
    /// Adds a configurable Cipher instance.
    public mutating func addConfigurable<
        Cipher: CipherProtocol
    >(cipher: Cipher, name: String) {
        addConfigurable(instance: cipher, unique: "cipher", name: name)
    }
    
    /// Adds a configurable Cipher class.
    public mutating func addConfigurable<
        Cipher: CipherProtocol & ConfigInitializable
    >(cipher: Cipher.Type, name: String) {
        addConfigurable(class: Cipher.self, unique: "cipher", name: name)
    }
    
    /// Resolves the configured Cipher.
    public func resolveCipher() throws -> CipherProtocol {
        return try resolve(
            unique: "cipher",
            file: "droplet",
            keyPath: ["cipher"],
            as: CipherProtocol.self,
            default: CryptoCipher.init
        )
    }
}
