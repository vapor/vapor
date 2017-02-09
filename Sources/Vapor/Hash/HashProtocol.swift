/// Creates hash digests
public protocol HashProtocol {
    /// Given a message, this method
    /// returns a hashed digest of that message.
    func make(_ message: Bytes) throws -> Bytes

    /// Checks whether a given digest was created
    /// by the supplied message.
    ///
    /// Returns true if the digest was created
    /// by the supplied message, false otherwise.
    func check(_ message: Bytes, matchesHash: Bytes) throws -> Bool

    /// Represents the current configuration
    /// of the hasher in case these values
    /// need to be stored alongside the hashes
    var configuration: Node { get }
}

/// Generic errors that can
/// occur during hashing. Especially,
/// those related to supporting or 
/// requiring keys.
public enum HashError: Error {
    case config(String)
    case unknown(Error)
}

// MARK: Convenience

import Core

extension HashProtocol {
    /// @see HashProtocol.make
    public func make(_ string: BytesConvertible) throws -> Bytes {
        return try make(string.makeBytes())
    }

    /// @see HashProtocol.check
    public func check(_ message: BytesConvertible, matchesDigest digest: BytesConvertible) throws -> Bool {
        let message = try message.makeBytes()
        let digest = try digest.makeBytes()
        return try check(
            message,
            matchesHash: digest
        )
    }
}
