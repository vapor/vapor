/// Capable of verifying that a supplied password matches a hash.
public protocol PasswordVerifier {
    /// Verifies that the supplied password matches a given hash.
    func verify<Password, Digest>(_ password: Password, created digest: Digest) throws -> Bool
        where Password: DataProtocol, Digest: DataProtocol
}
