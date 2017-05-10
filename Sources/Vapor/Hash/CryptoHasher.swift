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
    public let encoding: CryptoEncoding

    /// Creates a CryptoHasher with the desired
    /// HMAC method and HashEncoding
    public init(method: Method, encoding: CryptoEncoding) {
        self.method = method
        self.encoding = encoding
    }

    /// Creates a CryptoHasher using a
    /// keyed HMAC algorithm.
    public convenience init(hmac: HMAC.Method, encoding: CryptoEncoding, key: Bytes) {
        self.init(method: .keyed(hmac, key: key), encoding: encoding)
    }

    /// Creates a CryptoHasher using a
    /// normal Hash algorithm.
    public convenience init(hash: Hash.Method, encoding: CryptoEncoding) {
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

        return encoding.encode(hash)
    }

    /// See HashProtocol.check
    public func check(_ message: Bytes, matchesHash digest: Bytes) throws -> Bool {
        return try make(message) == digest
    }
}

// MARK: Config

extension CryptoHasher: ConfigInitializable {
    /// Creates a crypto hasher from a Config object
    public convenience init(config: Configs.Config) throws {
        guard let crypto = config["crypto"] else {
            throw ConfigError.missingFile("crypto")
        }

        // Method
        guard let methodString = crypto["hash", "method"]?.string else {
            throw ConfigError.missing(
                key: ["hash", "method"],
                file: "crypto",
                desiredType: String.self
            )
        }

        // Encoding
        guard let encodingString = crypto["hash", "encoding"]?.string else {
            throw ConfigError.missing(
                key: ["hash", "encoding"],
                file: "crypto",
                desiredType: String.self
            )
        }

        guard let encoding = try CryptoEncoding(encodingString) else {
            throw ConfigError.unsupported(
                value: encodingString,
                key: ["hash", "encoding"],
                file: "crypto"
            )
        }

        let method: Method

        // Key
        if let encodedKey = crypto["hash", "key"]?.bytes {
            guard let hmac = try HMAC.Method(methodString) else {
                throw ConfigError.unsupported(
                    value: methodString,
                    key: ["hash", "method"],
                    file: "crypto"
                )
            }
            
            let key = encoding.decode(encodedKey)
            if key.allZeroes {
                let log = try config.resolveLog()
                log.warning("The current hash key \"\(encodedKey.makeString())\" is not secure.")
                log.warning("Update hash.key in Config/crypto.json before using in production.")
                log.info("Use `openssl rand -base64 <length>` to generate a random string.")
            }

            method = .keyed(hmac, key: key)
        } else {
            guard let hash = try Hash.Method(methodString) else {
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
    public init?(_ string: String) throws {
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
    public init?(_ string: String) throws {
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
