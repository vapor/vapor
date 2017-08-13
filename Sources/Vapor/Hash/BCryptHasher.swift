import Bits
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
    public init(config: BCryptHasherConfig) {
        self.cost = config.cost
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

public struct BCryptHasherConfig {
    public let cost: UInt
    public init(cost: UInt = Salt.defaultCost) {
        self.cost = cost
    }
}
