import Crypto

/// Create normal and keyed hashes
/// using the available HMAC methods from
/// the vapor/crypto package.
public final class CryptoHasher: HashProtocol {
    /// The specified method, either keyed
    /// HMAC or normal hashing.
    public let method: Method

    /// The encoding used to format
    /// hashed bytes.
    public let encoding: Encoding

    /// Creates a CryptoHasher with the desired
    /// HMAC method and HashEncoding
    public init(method: Method, encoding: Encoding) {
        self.method = method
        self.encoding = encoding
    }

    /// Creates a CryptoHasher using a
    /// keyed HMAC algorithm.
    public convenience init(hmac: HMAC.Method, encoding: Encoding, key: Bytes) {
        self.init(method: .keyed(hmac, key: key), encoding: encoding)
    }

    /// Creates a CryptoHasher using a
    /// normal Hash algorithm.
    public convenience init(hash: Hash.Method, encoding: Encoding) {
        self.init(method: .normal(hash), encoding: encoding)
    }

    /// An exhaustive list of ways
    /// the hasher can hash data.
    public enum Method {
        case keyed(HMAC.Method, key: Bytes)
        case normal(Hash.Method)
    }

    /// See HashProtocol.make
    public func make(_ message: Bytes) throws -> Bytes {
        let hash: Bytes

        switch method {
        case .keyed(let method, let key):
            hash = try HMAC.make(method, message, key: key)
        case .normal(let method):
            hash = try Hash.make(method, message)
        }

        switch encoding {
        case .base64:
            return hash.base64Encoded
        case .hex:
            return hash.hexString.makeBytes()
        case .plain:
            return hash
        }
    }

    /// See HashProtocol.check
    public func check(_ message: Bytes, matchesHash digest: Bytes) throws -> Bool {
        return try make(message) == digest
    }

    /// Exhaustive list of methods
    /// by which a hash can be encoded.
    public enum Encoding {
        case hex
        case base64
        case plain
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

        let method: Method

        // Key
        if let key = config["crypto", "hash", "key"]?.string {
            guard let hmac = try HMAC.Method(from: methodString) else {
                throw ConfigError.unsupported(
                    value: methodString,
                    key: ["hash", "method"],
                    file: "crypto"
                )
            }

            method = .keyed(hmac, key: key.makeBytes())
        } else {
            guard let hash = try Hash.Method(from: methodString) else {
                throw ConfigError.unsupported(
                    value: methodString,
                    key: ["hash", "method"],
                    file: "crypto"
                )
            }

            method = .normal(hash)
        }

        self.init(method: method, encoding: encoding)
    }
}

// MARK: String Initializable

extension HMAC.Method: StringInitializable {
    public init?(from string: String) throws {
        switch string {
        case "sha1":
            self = .sha1
        case "sha224":
            self = .sha224
        case "sha256":
            self = .sha256
        case "sha384":
            self = .sha384
        case "sha512":
            self = .sha512
        case "md4":
            self = .md4
        case "md5":
            self = .md5
        case "ripemd160":
            self = .ripemd160
        case "whirlpool":
            self = .whirlpool
        default:
            return nil
        }
    }
}

extension Hash.Method: StringInitializable {
    public init?(from string: String) throws {
        switch string {
        case "sha1":
            self = .sha1
        case "sha224":
            self = .sha224
        case "sha256":
            self = .sha256
        case "sha384":
            self = .sha384
        case "sha512":
            self = .sha512
        case "md4":
            self = .md4
        case "md5":
            self = .md5
        case "ripemd160":
            self = .ripemd160
        default:
            return nil
        }
    }
}

extension CryptoHasher.Encoding: StringInitializable {
    public init?(from string: String) throws {
        switch string {
        case "hex":
            self = .hex
        case "base64":
            self = .base64
        case "plain":
            self = .plain
        default:
            return nil
        }
    }
}
