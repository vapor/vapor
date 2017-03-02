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
}

// MARK: Convenience

import Core

extension HashProtocol {
    /// See HashProtocol.make
    public func make(_ string: BytesConvertible) throws -> Bytes {
        return try make(string.makeBytes())
    }

    /// See HashProtocol.check
    public func check(_ message: BytesConvertible, matchesHash digest: BytesConvertible) throws -> Bool {
        let message = try message.makeBytes()
        let digest = try digest.makeBytes()
        return try check(
            message,
            matchesHash: digest
        )
    }
}
