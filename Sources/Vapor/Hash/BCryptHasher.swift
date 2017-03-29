import BCrypt

/// Create BCrypt hashes using the 
/// vapor/crypto package.
public final class BCryptHasher: HashProtocol {
    /// The cost factor increases the amount
    /// of work required to create the hash,
    /// increasing its resistance to brute force.
    public let cost: UInt

    /// Create a BCryptHasher using the
    /// specified work factor.
    ///
    /// See BCryptHasher.workFactor
    public init(cost: UInt = Salt.defaultCost) {
        self.cost = cost
    }

    /// See HashProtocol.make
    public func make(_ message: Bytes) throws -> Bytes {
        let salt = try BCrypt.Salt(cost: cost)
        return try BCrypt.Hash.make(message: message.makeString(), with: salt)
    }

    /// See HashProtocol.check
    public func check(_ message: Bytes, matchesHash digest: Bytes) throws -> Bool {
        return try BCrypt.Hash.verify(
            message: message,
            matches: digest
        )
    }
}

// MARK: Configuration

extension BCryptHasher: ConfigInitializable {
    /// Creates a bcrypt hasher from a Config object
    public convenience init(config: Settings.Config) throws {
        guard let cost = config["bcrypt", "cost"]?.uint else {
            throw ConfigError.missing(
                key: ["cost"],
                file: "bcrypt",
                desiredType: UInt.self
            )
        }

        self.init(cost: cost)
    }
}
