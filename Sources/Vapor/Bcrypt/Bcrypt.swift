import CBcrypt

/// Creates and verifies Bcrypt hashes.
///
/// Use Bcrypt to create hashes for sensitive information like passwords.
///
///     try BCrypt.hash("vapor", cost: 4)
///
/// Bcrypt uses a random salt each time it creates a hash. To verify hashes, use the `verify(_:matches)` method.
///
///     let hash = try BCrypt.hash("vapor", cost: 4)
///     try BCrypt.verify("vapor", created: hash) // true
///
/// https://en.wikipedia.org/wiki/Bcrypt
public final class Bcrypt {
    /// Specific Bcrypt algorithm.
    public enum Algorithm: String, RawRepresentable {
        /// older version
        case _2a = "2a"
        /// format specific to the crypt_blowfish Bcrypt implementation, identical to `2b` in all but name.
        case _2y = "2y"
        /// latest revision of the official Bcrypt algorithm, current default
        case _2b = "2b"
//
//        /// Revision's length, including the `$` symbols
//        var revisionCount: Int {
//            return 4
//        }
//
//        /// Salt's length (includes revision and cost info)
//        var fullSaltCount: Int {
//            return 29
//        }
//
//        /// Checksum's length
//        var checksumCount: Int {
//            return 31
//        }
//
//        /// Salt's length (does NOT include neither revision nor cost info)
//        static var saltCount: Int {
//            return 22
//        }
    }

    public enum Error: Swift.Error, CustomStringConvertible, LocalizedError {
        case invalidCost(Int)
        case invalidSalt
        case invalidDigest
        case hashFailure

        public var errorDescription: String? {
            return self.description
        }

        public var description: String {
            switch self {
            case .invalidCost(let cost):
                return "Cost should be between 4 and 31: \(cost)"
            case .invalidSalt:
                return "Provided salt has the incorrect format"
            case .invalidDigest:
                return "Provided digest has the incorrect format"
            case .hashFailure:
                return "Unable to compute Bcrypt hash"
            }
        }
    }

    public struct Salt: CustomStringConvertible {
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
        /// - returns: Complete salt
        public static func generate(cost: Int, algorithm: Algorithm = ._2b) -> Salt {
            return .init(algorithm: algorithm, cost: cost, seed: .random(count: 16))
        }

        public let algorithm: Algorithm
        public let cost: Int
        public let seed: [UInt8]

        public var string: String {
            return "$"
                + self.algorithm.rawValue
                + "$"
                + (self.cost < 10 ? "0\(self.cost)" : "\(self.cost)" ) // 0 padded
                + "$"
                + encodeSalt(self.seed)
        }

        public init(algorithm: Algorithm, cost: Int, seed: [UInt8]) {
            self.algorithm = algorithm
            self.cost = cost
            self.seed = seed
        }

        public var description: String {
            return self.string
        }
    }

    public struct Digest: CustomStringConvertible {
        public let salt: Salt
        public let bytes: [UInt8]

        public var string: String {
            return "$"
                + self.salt.algorithm.rawValue
                + "$"
                + (self.salt.cost < 10 ? "0\(self.salt.cost)" : "\(self.salt.cost)" ) // 0 padded
                + "$"
                + encodeDigest(self.salt.seed + self.bytes)
        }

        public init(string: String) throws {
            let parts = string.split(separator: "$", omittingEmptySubsequences: true)
            guard parts.count == 3 else {
                throw Error.invalidSalt
            }
            guard let algorithm = Algorithm(rawValue: String(parts[0])) else {
                throw Error.invalidSalt
            }
            guard let cost = Int(parts[1]) else {
                throw Error.invalidSalt
            }
            guard let payload = decodeDigest(String(parts[2])) else {
                throw Error.invalidDigest
            }
            print(payload)
            print(payload.count)
            self.init(
                salt: .init(algorithm: algorithm, cost: cost, seed: .init(payload[0..<16])),
                bytes: .init(payload[16...])
            )
        }

        public init(salt: Salt, bytes: [UInt8]) {
            self.salt = salt
            self.bytes = bytes
        }

        public var description: String {
            return self.string
        }
    }

    /// Creates a BCrypt digest for the supplied data.
    ///
    /// Salt must be provided
    ///
    ///     try BCrypt.hash("vapor")
    ///
    /// - parameters:
    ///     - plaintext: Plaintext data to digest.
    ///     - salt: Optional salt for this hash. If omitted, a random salt will be generated.
    ///             The salt must be 16-bytes if provided by the user (without cost, revision data)
    /// - throws: `CryptoError` if hashing fails or if data conversion fails.
    /// - returns: BCrypt hash for the supplied plaintext data.
    public static func hash(_ plaintext: String, salt: Salt = .generate(cost: 16)) throws -> Digest {
        return try self.hash([UInt8](plaintext.utf8), salt: salt)
    }

    /// Creates a BCrypt digest for the supplied data.
    ///
    /// Salt must be provided
    ///
    ///     try BCrypt.hash("vapor")
    ///
    /// - parameters:
    ///     - plaintext: Plaintext data to digest.
    ///     - salt: Optional salt for this hash. If omitted, a random salt will be generated.
    ///             The salt must be 16-bytes if provided by the user (without cost, revision data)
    /// - throws: `CryptoError` if hashing fails or if data conversion fails.
    /// - returns: BCrypt hash for the supplied plaintext data.
    public static func hash<Plaintext>(_ plaintext: Plaintext, salt: Salt = .generate(cost: 16)) throws -> Digest
        where Plaintext: DataProtocol
    {
        guard salt.cost >= BCRYPT_MINLOGROUNDS && salt.cost <= 31 else {
            throw Error.invalidCost(salt.cost)
        }

        let plaintext = plaintext.copyBytes()

        let digest = UnsafeMutablePointer<UInt8>.allocate(capacity: 24)
        defer {
            digest.deinitialize(count: 24)
            digest.deallocate()
        }

        guard bcrypt_digest(
            plaintext,
            plaintext.count,
            numericCast(salt.cost),
            salt.seed,
            digest
        ) == 0 else {
            throw Error.hashFailure
        }
        return .init(salt: salt, bytes: .init(UnsafeBufferPointer(start: digest, count: 24)))
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
    public static func verify(_ plaintext: String, created digest: Digest) throws -> Bool {
        return try self.verify([UInt8](plaintext.utf8), created: digest)
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
    public static func verify<Plaintext>(_ plaintext: Plaintext, created digest: Digest) throws -> Bool
        where Plaintext: DataProtocol
    {
        let check = try self.hash(plaintext, salt: digest.salt)
        print("digest: \(digest.string)")
        print("ocheck: \(check.string)")
        return check.string
            .secureCompare(to: digest.string)
    }
}

private func encodeSalt(_ bytes: [UInt8]) -> String {
    assert(bytes.count == 16)
    let encoded = UnsafeMutablePointer<Int8>.allocate(capacity: 24)
    defer {
        encoded.deinitialize(count: 24)
        encoded.deallocate()
    }
    encode_base64(encoded, bytes, 16)
    return String(cString: encoded)
}

private func encodeDigest(_ bytes: [UInt8]) -> String {
    assert(bytes.count == 40)
    let encoded = UnsafeMutablePointer<Int8>.allocate(capacity: 53)
    defer {
        encoded.deinitialize(count: 53)
        encoded.deallocate()
    }
    encode_base64(encoded, bytes, 40)
    return String(cString: encoded)
}

private func decodeDigest(_ encoded: String) -> [UInt8]? {
    assert(encoded.utf8.count == 53)
    let decoded = UnsafeMutablePointer<UInt8>.allocate(capacity: 40)
    defer {
        decoded.deinitialize(count: 40)
        decoded.deallocate()
    }
    decode_base64(decoded, 60, encoded)
    return .init(UnsafeBufferPointer(start: decoded, count: 40))
}

public struct Base64 {
    let lookupTable: [Character]

    init(lookupTable: String) {
        self.lookupTable = .init(lookupTable)
    }

    public static var bcrypt: Base64 {
        return .init(lookupTable: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789./")
    }

    public func encode(_ decoded: [UInt8]) -> String {
        var encoded = ""
        func push(_ code: UInt8) {
            encoded.append(self.lookupTable[numericCast(code)])
        }

        var iterator = decoded.makeIterator()
        while let one = iterator.next() {
            push((one & 0b11111100) >> 2)
            if let two = iterator.next() {
                if let three = iterator.next() {
                    push(((one & 0b00000011) << 4) | ((two & 0b11110000) >> 4))
                    push(((two & 0b00001111)) << 2 | ((three & 0b11000000)) >> 6)
                    push(three & 0b00111111)
                } else {
                    push(((one & 0b00000011) << 4) | ((two & 0b11110000) >> 4))
                    push((two & 0b00001111) << 2)
                }
            } else {
                push((one & 0b00000011) << 4)
            }
        }
        return encoded
    }
}
