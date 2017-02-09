import BCrypt

/// Create BCrypt hashes using the 
/// vapor/crypto package.
public final class BCryptHasher: HashProtocol {
    /// The work factor increases the amount
    /// of work required to create the hash,
    /// increasing its security.
    public let workFactor: Int

    /// Create a BCryptHasher using the
    /// specified work factor.
    ///
    /// @see BCryptHasher.workFactor
    public init(workFactor: Int = 10) {
        self.workFactor = workFactor
    }

    /// @see HashProtocol.make
    public func make(_ message: Bytes, key: Bytes?) throws -> Bytes {
        guard key == nil else {
            throw Error.keyNotAllowed
        }

        let salt = BCryptSalt(cost: workFactor)
        return BCrypt.hash(password: message.string, salt: salt).bytes
    }

    /// @see HashProtocol.check
    public func check(_ message: Bytes, matches digest: Bytes, key: Bytes?) throws -> Bool {
        return try BCrypt.verify(
            password: message.string,
            matchesHash: digest.string
        )
    }

    /// @see HashProtocol.configuration
    public var configuration: Node {
        return Node.object([
            "workFactor": Node.number(.int(workFactor))
        ])
    }

    /// Errors that may arise when 
    /// using or configuring this hasher.
    public enum Error: Swift.Error {
        case keyNotAllowed
        case unknown(Swift.Error)
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
