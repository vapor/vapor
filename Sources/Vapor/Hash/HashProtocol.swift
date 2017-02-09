/// Creates hashes and keyed hashes
public protocol HashProtocol {
    /// Given a message, this method
    /// returns a hashed digest of that message.
    ///
    /// An optional key can be passed to
    /// implementations that support it
    /// generating a keyed hash.
    func make(_ message: Bytes, key: Bytes?) throws -> Bytes

    /// Checks whether a given digest was created
    /// by the supplied message.
    ///
    /// An optional key can be passed to
    /// implementations that support it
    /// generating a keyed hash.
    ///
    /// Returns true if the digest was created
    /// by the supplied message, false otherwise.
    func check(_ message: Bytes, matches: Bytes, key: Bytes?) throws -> Bool

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
    case keyUnsupported
    case keyRequired
    case config(String)
    case unknown(Error)
}

// MARK: Convenience

import Core

extension HashProtocol {
    /// @see HashProtocol.make
    public func make(
        _ string: BytesConvertible,
        key: BytesConvertible? = nil
    ) throws -> Bytes {
        return try make(string.makeBytes(), key: key?.makeBytes())
    }

    /// @see HashProtocol.check
    public func check(
        _ message: BytesConvertible,
        matches digest: BytesConvertible,
        key: BytesConvertible? = nil
    ) throws -> Bool {
        let message = try message.makeBytes()
        let digest = try digest.makeBytes()
        return try check(
            message,
            matches: digest, 
            key: key?.makeBytes()
        )
    }
}
