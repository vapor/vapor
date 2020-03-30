/// Capable of hashing a supplied password
public protocol PasswordHasher {
    func `for`(_ request: Request) -> PasswordHasher
    // Take a plaintext password and return a hashed password
    func hash(_ plaintext: String) throws -> String
}

/// Simply returns the plaintext as the hash, useful for testing
/// Don't use this in production
extension PlaintextVerifier: PasswordHasher {
    public func hash(_ plaintext: String) throws -> String {
        return plaintext
    }
    
    public func `for`(_ request: Request) -> PasswordHasher {
        return PlaintextVerifier()
    }
}
