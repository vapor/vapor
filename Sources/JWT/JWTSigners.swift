/// A collection of signers labeled by kid.
public final class JWTSigners {
    /// Internal storage
    private var storage: [String: JWTSigner]

    /// Create a new collection of signers
    public init() {
        self.storage = [:]
    }

    /// Adds a new signer
    public func use(_ signer: JWTSigner, kid: String) {
        storage[kid] = signer
    }

    /// Gets a signer for the `kid` if one exists
    public func signer(kid: String) -> JWTSigner? {
        return storage[kid]
    }

    /// Returns a signer for the `kid` or throws an error
    public func requireSigner(kid: String) throws -> JWTSigner {
        guard let signer = self.signer(kid: kid) else {
            throw JWTError(identifier: "unknownKID", reason: "No signers are available for the supplied `kid`")
        }
        return signer
    }
}
