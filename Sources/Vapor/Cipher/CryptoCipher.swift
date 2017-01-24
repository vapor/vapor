import Cipher
import Core
import Foundation

public final class CryptoCipher: CipherProtocol {
    public let method: Cipher.Method

    public var defaultKey: Bytes
    public var defaultIV: Bytes?

    public enum Error: Swift.Error {
        case config(String)
    }

    public init(method: Cipher.Method, defaultKey: Bytes, defaultIV: Bytes?) {
        self.method = method
        self.defaultKey = defaultKey
        self.defaultIV = defaultIV
    }

    public func encrypt(_ bytes: Bytes, key: Bytes, iv: Bytes?) throws -> Bytes {
        let cipher = try Cipher(method, key: key, iv: iv)
        return try cipher.encrypt(bytes)
    }

    public func decrypt(_ bytes: Bytes, key: Bytes, iv: Bytes?) throws -> Bytes {
        let cipher = try Cipher(method, key: key, iv: iv)
        return try cipher.decrypt(bytes)
    }
}

extension CryptoCipher: ConfigInitializable {

    public convenience init(config: Settings.Config) throws {
        guard let methodString = config["crypto", "cipher", "method"]?.string else {
            throw Error.config("No `cipher.method` found in `crypto.json` config.")
        }

        let method: Cipher.Method
        switch methodString {
        case "chacha20":
            method = .chacha20
        case "aes128":
            method = .aes128(.cbc)
        case "aes256":
            method = .aes256(.cbc)
        default:
            throw Error.config("Unknown cipher method '\(methodString)'.")
        }

        guard let key = config["crypto", "cipher", "key"]?.string?.bytes else {
            throw Error.config("No `cipher.key` found in `crypto.json` config.")
        }

        let iv = config["crypto", "cipher", "iv"]?.string?.bytes

        switch method {
        case .chacha20:
            if key.count != 32 {
                throw Error.config("Chacha20 cipher key must be 32 bytes.")
            }
            if iv == nil {
                throw Error.config("Chacha20 cipher requires an initialization vector (iv).")
            } else if iv?.count != 8 {
                throw Error.config("Chacha20 initialization vector (iv) must be 8 bytes.")
            }
        case .aes128:
            if key.count != 16 {
                throw Error.config("AES-128 cipher key must be 16 bytes.")
            }
        case .aes256:
            if key.count != 16 {
                throw Error.config("AES-256 cipher key must be 16 bytes.")
            }
        default:
            break
        }

        self.init(method: method, defaultKey: key, defaultIV: iv)
    }
}
