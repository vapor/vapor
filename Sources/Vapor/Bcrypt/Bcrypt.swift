import CVaporBcrypt
import Foundation

// MARK: BCrypt

/// Creates and verifies BCrypt hashes.
///
/// Use BCrypt to create hashes for sensitive information like passwords.
///
///     try BCrypt.hash("vapor", cost: 4)
///
/// BCrypt uses a random salt each time it creates a hash. To verify hashes, use the `verify(_:matches)` method.
///
///     let hash = try BCrypt.hash("vapor", cost: 4)
///     try BCrypt.verify("vapor", created: hash) // true
///
/// https://en.wikipedia.org/wiki/Bcrypt
public var Bcrypt: BCryptDigest {
    return .init()
}

/// Creates and verifies BCrypt hashes. Normally you will not need to initialize one of these classes and you will
/// use the global `BCrypt` convenience instead.
///
///     try BCrypt.hash("vapor", cost: 4)
///
/// See `BCrypt` for more information.
public final class BCryptDigest {
    /// Creates a new `BCryptDigest`. Use the global `BCrypt` convenience variable.
    public init() {}

    /// Creates a new BCrypt hash with a randomly generated salt.
    /// The result can be stored in a database.
    public func hash(_ plaintext: String, cost: Int = 12) throws -> String {
        guard cost >= BCRYPT_MINLOGROUNDS && cost <= 31 else {
            throw BcryptError.invalidCost
        }
        return try self.hash(plaintext, salt: self.generateSalt(cost: cost))
    }

    public func hash(_ plaintext: String, salt: String) throws -> String {
        guard isSaltValid(salt) else {
            throw BcryptError.invalidSalt
        }

        let originalAlgorithm: Algorithm
        if salt.count == Algorithm.saltCount {
            // user provided salt
            originalAlgorithm = ._2b
        } else {
            // full salt, not user provided
            let revisionString = String(salt.prefix(4))
            if let parsedRevision = Algorithm(rawValue: revisionString) {
                originalAlgorithm = parsedRevision
            } else {
                throw BcryptError.invalidSalt
            }
        }

        // OpenBSD doesn't support 2y revision.
        let normalizedSalt: String
        if originalAlgorithm == Algorithm._2y {
            // Replace with 2b.
            normalizedSalt = Algorithm._2b.rawValue + salt.dropFirst(originalAlgorithm.revisionCount)
        } else {
            normalizedSalt = salt
        }

        let hashedBytes = UnsafeMutablePointer<Int8>.allocate(capacity: 128)
        defer { hashedBytes.deallocate() }
        let hashingResult = vapor_bcrypt_hashpass(
            plaintext,
            normalizedSalt,
            hashedBytes,
            128
        )

        guard hashingResult == 0 else {
            throw BcryptError.hashFailure
        }
        return originalAlgorithm.rawValue
            + String(cString: hashedBytes)
            .dropFirst(originalAlgorithm.revisionCount)
    }

    /// Verifies an existing BCrypt hash matches the supplied plaintext value. Verification works by parsing the salt and version from
    /// the existing digest and using that information to hash the plaintext data. If hash digests match, this method returns `true`.
    ///
    ///     let hash = try BCrypt.hash("vapor", cost: 4)
    ///     try BCrypt.verify("vapor", created: hash) // true
    ///     try BCrypt.verify("foo", created: hash) // false
    ///
    /// - parameters:
    ///     - plaintext: Plaintext data to digest and verify.
    ///     - hash: Existing BCrypt hash to parse version, salt, and existing digest from.
    /// - throws: `CryptoError` if hashing fails or if data conversion fails.
    /// - returns: `true` if the hash was created from the supplied plaintext data.
    public func verify(_ plaintext: String, created hash: String) throws -> Bool {
        guard let hashVersion = Algorithm(rawValue: String(hash.prefix(4))) else {
            throw BcryptError.invalidHash
        }

        let hashSalt = String(hash.prefix(hashVersion.fullSaltCount))
        guard !hashSalt.isEmpty, hashSalt.count == hashVersion.fullSaltCount else {
            throw BcryptError.invalidHash
        }

        let hashChecksum = String(hash.suffix(hashVersion.checksumCount))
        guard !hashChecksum.isEmpty, hashChecksum.count == hashVersion.checksumCount else {
            throw BcryptError.invalidHash
        }

        let messageHash = try self.hash(plaintext, salt: hashSalt)
        let messageHashChecksum = String(messageHash.suffix(hashVersion.checksumCount))
        return messageHashChecksum.secureCompare(to: hashChecksum)
    }

    // MARK: Private

    /// Generates string (29 chars total) containing the algorithm information + the cost + base-64 encoded 22 character salt
    ///
    ///     E.g:  $2b$05$J/dtt5ybYUTCJ/dtt5ybYO
    ///           $AA$ => Algorithm
    ///              $CC$ => Cost
    ///                  SSSSSSSSSSSSSSSSSSSSSS => Salt
    ///
    /// Allowed charset for the salt: [./A-Za-z0-9]
    ///
    /// - parameters:
    ///     - cost: Desired complexity. Larger `cost` values take longer to hash and verify.
    ///     - algorithm: Revision to use (2b by default)
    ///     - seed: Salt (without revision data). Generated if not provided. Must be 16 chars long.
    /// - returns: Complete salt
    private func generateSalt(cost: Int, algorithm: Algorithm = ._2b, seed: [UInt8]? = nil) -> String {
        let randomData: [UInt8]
        if let seed = seed {
            randomData = seed
        } else {
            randomData = [UInt8].random(count: 16)
        }
        let encodedSalt = base64Encode(randomData)

        return
            algorithm.rawValue + (cost < 10 ? "0\(cost)" : "\(cost)")  // 0 padded
            + "$" + encodedSalt
    }

    /// Checks whether the provided salt is valid or not
    ///
    /// - parameters:
    ///     - salt: Salt to be checked
    /// - returns: True if the provided salt is valid
    private func isSaltValid(_ salt: String) -> Bool {
        // Includes revision and cost info (count should be 29)
        let revisionString = String(salt.prefix(4))
        if let algorithm = Algorithm(rawValue: revisionString) {
            return salt.count == algorithm.fullSaltCount
        } else {
            // Does not include revision and cost info (count should be 22)
            return salt.count == Algorithm.saltCount
        }
    }

    /// Encodes the provided plaintext using OpenBSD's custom base-64 encoding (Radix-64)
    ///
    /// - parameters:
    ///     - data: Data to be base64 encoded.
    /// - returns: Base 64 encoded plaintext
    private func base64Encode(_ data: [UInt8]) -> String {
        let encodedBytes = UnsafeMutablePointer<Int8>.allocate(capacity: 25)
        defer { encodedBytes.deallocate() }
        let res = data.withUnsafeBytes { bytes in
            vapor_encode_base64(encodedBytes, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), bytes.count)
        }
        assert(res == 0, "base64 convert failed")
        return String(cString: encodedBytes)
    }

    /// Specific BCrypt algorithm.
    private enum Algorithm: String, RawRepresentable {
        /// older version
        case _2a = "$2a$"
        /// format specific to the crypt_blowfish BCrypt implementation, identical to `2b` in all but name.
        case _2y = "$2y$"
        /// latest revision of the official BCrypt algorithm, current default
        case _2b = "$2b$"

        /// Revision's length, including the `$` symbols
        var revisionCount: Int {
            return 4
        }

        /// Salt's length (includes revision and cost info)
        var fullSaltCount: Int {
            return 29
        }

        /// Checksum's length
        var checksumCount: Int {
            return 31
        }

        /// Salt's length (does NOT include neither revision nor cost info)
        static var saltCount: Int {
            return 22
        }
    }
}

public enum BcryptError: Swift.Error, CustomStringConvertible, LocalizedError {
    case invalidCost
    case invalidSalt
    case hashFailure
    case invalidHash

    public var errorDescription: String? {
        return self.description
    }

    public var description: String {
        return "Bcrypt error: \(self.reason)"
    }

    var reason: String {
        switch self {
        case .invalidCost:
            return "Cost should be between 4 and 31"
        case .invalidSalt:
            return "Provided salt has the incorrect format"
        case .hashFailure:
            return "Unable to compute hash"
        case .invalidHash:
            return "Invalid hash formatting"
        }
    }
}
