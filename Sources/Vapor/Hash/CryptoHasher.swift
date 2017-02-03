import HMAC
import Hash
import Core
import libc

/**
    Create SHA + HMAC hashes with the
    Hash class by applying this driver.
*/
public final class CryptoHasher: HashProtocol {
    public let method: HMAC.Method

    /**
        HMAC key.
    */
    public let defaultKey: Bytes?

    /**
        Create a CryptoHasher with the 
        given method and defaultKey.
    */
    public init(method: HMAC.Method, defaultKey: Bytes?) {
        self.method = method
        self.defaultKey = defaultKey
    }

    /**
        Hash given string with key

        - parameter message: message to hash
        - parameter key: key to hash with
        - parameter encoding: string encoding for resulting hash

        - returns: a hashed string
     */
    public func make(_ message: Bytes, key: Bytes?) throws -> Bytes {
        let hash: Bytes

        if let key = key {
            hash = try HMAC.make(method, message, key: key)
        } else {
            hash = try Hash.make(try method.hashMethod(), message)
        }

        return hash
    }

    public enum Error: Swift.Error {
        case hashWithoutKeyUnsupported
        case config(String)
    }
}

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
            throw CryptoHasher.Error.hashWithoutKeyUnsupported
        }
    }
}

extension CryptoHasher: ConfigInitializable {
    public convenience init(config: Settings.Config) throws {
        guard let methodString = config["crypto", "hash", "method"]?.string else {
            throw Error.config("No `hash.method` found in `crypto.json` config.")
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
            throw Error.config("Unknown hash method '\(methodString)'.")
        }

        guard let key = config["crypto", "hash", "key"]?.string?.bytes else {
            throw Error.config("No `hash.key` found in `crypto.json` config.")
        }

        self.init(method: method, defaultKey: key)
    }
}
