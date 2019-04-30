/// Capable of verifying that a supplied password matches a hash.
public protocol PasswordVerifier {
    /// Verifies that the supplied password matches a given hash.
    func verify(_ password: CryptoData, created hash: CryptoData) throws -> Bool
}

extension BCryptDigest: PasswordVerifier { }

/// Simply compares the password to the hash.
/// Don't use this in production.
public struct PlaintextVerifier: PasswordVerifier {
    /// Create a new plaintext verifier.
    public init() {}

    /// See PasswordVerifier.verify
    public func verify(_ password: CryptoData, created hash: CryptoData) -> Bool {
        return password.string() == hash.string()
    }
}
