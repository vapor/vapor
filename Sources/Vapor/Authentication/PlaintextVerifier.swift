/// Simply compares the password to the hash.
/// Don't use this in production - use BCrypt
public struct PlaintextVerifier: PasswordVerifier, PasswordHasher {
    /// Create a new plaintext verifier.
    public init() {}

    /// See PasswordVerifier.verify
    public func verify<Password, Digest>(_ password: Password, created digest: Digest) throws -> Bool
        where Password: DataProtocol, Digest: DataProtocol
    {
        return password.copyBytes() == digest.copyBytes()
    }
    
    public func verify(_ password: String, created digest: String) throws -> Bool {
        return password == digest
    }
    
    public func hash(_ plaintext: String) throws -> String {
        return plaintext
    }
}

extension PlaintextVerifier {
    public func `for`(_ request: Request) -> PasswordVerifier {
        return PlaintextVerifier()
    }
    
    public func `for`(_ request: Request) -> PasswordHasher {
        return PlaintextVerifier()
    }
}

extension Application.PasswordVerifiers {
    var plaintext: PlaintextVerifier {
        return .init()
    }
}

extension Application.PasswordHashers {
    var plaintext: PlaintextVerifier {
        return .init()
    }
}

extension Application.PasswordVerifiers.Provider {
    public static var plaintext: Self {
        .init {
            $0.passwordVerifiers.use { $0.passwordVerifiers.plaintext }
        }
    }
}

extension Application.PasswordHashers.Provider {
    public static var plaintext: Self {
        .init {
            $0.passwordHashers.use { $0.passwordHashers.plaintext }
        }
    }
}
