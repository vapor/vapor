import BCrypt

/// Create BCrypt hashes using the 
/// vapor/crypto package.
public final class BCryptHasher: HashProtocol {
    /// The work factor increases the amount
    /// of work required to create the hash,
    /// increasing its resistance to brute force.
    public let workFactor: Int

    /// Create a BCryptHasher using the
    /// specified work factor.
    ///
    /// See BCryptHasher.workFactor
    public init(workFactor: Int = 10) {
        self.workFactor = workFactor
    }

    /// See HashProtocol.make
    public func make(_ message: Bytes) throws -> Bytes {
        let salt = BCryptSalt(cost: workFactor)
        return BCrypt.hash(password: message.string, salt: salt).bytes
    }

    /// See HashProtocol.check
    public func check(_ message: Bytes, matchesHash digest: Bytes) throws -> Bool {
        return try BCrypt.verify(
            password: message.string,
            matchesHash: digest.string
        )
    }
}

// MARK: Configuration

extension BCryptHasher: ConfigInitializable {
    /// Creates a bcrypt hasher from a Config object
    public convenience init(config: Settings.Config) throws {
        guard let workFactor = config["bcrypt", "workFactor"]?.int else {
            throw ConfigError.missing(
                key: ["workFactor"],
                file: "bcrypt",
                desiredType: Int.self
            )
        }

        self.init(workFactor: workFactor)
    }
}
