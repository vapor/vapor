/// Simply compares the password to the hash.
/// Don't use this in production - use BCrypt
public struct PlaintextVerifier: PasswordService, PasswordVerifier {
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
    
    public func hash<Plaintext>(_ plaintext: Plaintext) throws -> String where Plaintext : DataProtocol {
        return String(decoding: plaintext, as: UTF8.self)
    }
}

extension PlaintextVerifier {
    public func `for`(_ request: Request) -> PasswordService {
        return PlaintextVerifier()
    }
}

extension Application.Passwords {
    var plaintext: PlaintextVerifier {
        return .init()
    }
}

extension Application.Passwords.Provider {
    public static var plaintext: Self {
        .init {
            $0.passwords.use { $0.passwords.plaintext }
        }
    }
}
