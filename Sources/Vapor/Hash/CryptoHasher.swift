import Bits
import Crypto
import Service

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
    public init(config: CryptoHasherConfig) {
        self.method = config.method
        self.encoding = config.encoding
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

public struct CryptoHasherConfig {
    public let method: CryptoHasher.Method
    public let encoding: CryptoEncoding

    public init(method: CryptoHasher.Method, encoding: CryptoEncoding) {
        self.method = method
        self.encoding = encoding
    }
}

// MARK: Service

extension CryptoHasher: ServiceType {
    /// See Service.name
    public static var serviceName: String {
        return "crypto"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [HashProtocol.self]
    }

    /// See Service.make
    public static func makeService(for container: Container) throws -> CryptoHasher? {
        return try CryptoHasher(config: container.make())
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
