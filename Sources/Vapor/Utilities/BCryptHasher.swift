import Crypto
import Foundation

/// A instance-based wrapper around Crypto.BCrypt.
public final class BCryptHasher {
    /// BCrypt salt cost
    private let cost: UInt

    /// BCrypt salt version.
    private let version: BCrypt.Salt.Version

    /// Generate a new salt.
    private var salt: BCrypt.Salt {
        return try! .init(.two(.y), cost: cost, bytes: nil) // will never throw if bytes is nil
    }

    /// Create a new BCryptHasher.
    public init(
        version: BCrypt.Salt.Version,
        cost: UInt
    ) {
        self.version = version
        self.cost = cost
    }

    /// Hash the supplied message data to a digest.
    public func make(_ message: Data) throws -> Data {
        return try BCrypt.make(message: message, with: salt)
    }

    /// Hash the supplied message data to a digest.
    public func make(_ message: String) throws -> String {
        return try String(data: BCrypt.make(message: message, with: salt), encoding: .utf8)!
    }

    /// Returns true if the message matches the supplied digest.
    public func verify(message: String, matches digest: String) throws -> Bool {
        return try BCrypt.verify(message: message, matches: digest)
    }

    /// Returns true if the message matches the supplied digest.
    public func verify(message: Data, matches digest: Data) throws -> Bool {
        return try BCrypt.verify(message: message, matches: digest)
    }
}
