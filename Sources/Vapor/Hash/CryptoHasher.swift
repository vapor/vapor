import HMAC
import Hash
import Core

/// Create normal and keyed hashes
/// using the available HMAC methods from
/// the vapor/crypto package.
public final class CryptoHasher: HashProtocol {
    /// The specified HMAC method will be
    /// used for creating keyed hashes and the
    /// HMAC method's hash method for all other hashes
    public let method: HMAC.Method

    /// The default encoding that will be
    /// used when the hash destination
    /// is a String
    public let encoding: Encoding

    /// An optional key can be passed to
    /// implementations that support it
    /// generating a keyed hash.
    public let key: Bytes?

    /// Creates a CryptoHasher with the desired
    /// HMAC method and HashEncoding
    public init(method: HMAC.Method, encoding: Encoding, key: Bytes?) {
        self.method = method
        self.encoding = encoding
        self.key = key
    }

    /// @see CryptoHasher.init(..., key: Bytes?)
    public convenience init(method: HMAC.Method, encoding: Encoding, key: BytesConvertible) throws {
        self.init(method: method, encoding: encoding, key: try key.makeBytes())
    }

    /// @see HashProtocol.make
    public func make(_ message: Bytes) throws -> Bytes {
        let hash: Bytes

        if let key = key {
            hash = try HMAC.make(method, message, key: key)
        } else {
            hash = try Hash.make(try method.hashMethod(), message)
        }

        switch encoding {
        case .base64:
            return hash.base64Encoded
        case .hex:
            return hash.hexString.bytes
        case .plain:
            return hash
        }
    }

    /// @see HashProtocol.check
    public func check(_ message: Bytes, matchesHash digest: Bytes) throws -> Bool {
        return try make(message) == digest
    }

    /// @see HashProtocol.configuration
    public var configuration: Node {
        return Node.object([
            "method": Node.string("\(method)")
        ])
    }

    /// Errors that may arise when
    /// using or configuring this hasher.
    public enum Error: Swift.Error {
        case unsupportedHashMethod
        case unknown(Swift.Error)
    }

    /// Exhaustive list of methods
    /// by which a hash can be encoded.
    public enum Encoding {
        case hex
        case base64
        case plain
    }
}

// MARK: HMAC -> Hash

extension HMAC.Method {
    func hashMethod() throws -> Hash.Method {
        switch self {
        case .sha1:
            return .sha1
        case .sha224:
            return .sha224
        case .sha256:
            return .sha256
        case .sha384:
            return .sha384
        case .sha512:
            return .sha512
        case .md4:
            return .md4
        case .md5:
            return .md5
        case .ripemd160:
            return .ripemd160
        default:
            throw CryptoHasher.Error.unsupportedHashMethod
        }
    }
}

// MARK: Config

extension CryptoHasher: ConfigInitializable {
    /// Creates a crypto hasher from a Config object
    public convenience init(config: Settings.Config) throws {
        // Method
        guard let methodString = config["crypto", "hash", "method"]?.string else {
            throw ConfigError.missing(
                key: ["hash", "method"],
                file: "crypto",
                desiredType: String.self
            )
        }

        let method: HMAC.Method
        switch methodString {
        case "sha1":
            method = .sha1
        case "sha224":
            method = .sha224
        case "sha256":
            method = .sha256
        case "sha384":
            method = .sha384
        case "sha512":
            method = .sha512
        case "md4":
            method = .md4
        case "md5":
            method = .md5
        case "ripemd160":
            method = .ripemd160
        default:
            throw ConfigError.unsupported(
                value: methodString,
                key: ["hash", "method"],
                file: "crypto"
            )
        }

        // Encoding
        guard let encodingString = config["crypto", "hash", "encoding"]?.string else {
            throw ConfigError.missing(
                key: ["hash", "encoding"],
                file: "crypto",
                desiredType: String.self
            )
        }

        guard let encoding = try Encoding(from: encodingString) else {
            throw ConfigError.unsupported(
                value: encodingString,
                key: ["hash", "encoding"],
                file: "crypto"
            )
        }

        // Key
        let key = config["crypto", "hash", "key"]?.string?.bytes

        self.init(method: method, encoding: encoding, key: key)
    }
}

extension CryptoHasher.Encoding: StringInitializable {
    public init?(from string: String) throws {
        switch string {
        case "hex":
            self = .hex
        case "base64":
            self = .base64
        default:
            return nil
        }
    }
}
