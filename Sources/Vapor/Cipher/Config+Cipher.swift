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
            return CryptoCipher(
                method: .aes256(.cbc),
                defaultKey: Bytes(repeating: 0, count: 16)
            )
        }
    }
}
