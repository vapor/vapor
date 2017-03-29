import Crypto
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
        case "aes128":
            method = .aes128(.cbc)
        case "aes256":
            method = .aes256(.cbc)
        default:
            if methodString == "chacha20" {
                print("Warning: chacha20 cipher is no longer available. Please use aes256 instead.")
            }
            throw Error.config("Unknown cipher method '\(methodString)'.")
        }

        guard let key = config["crypto", "cipher", "key"]?.string?.makeBytes() else {
            throw Error.config("No `cipher.key` found in `crypto.json` config.")
        }

        let iv = config["crypto", "cipher", "iv"]?.string?.makeBytes()

        switch method {
        case .aes128:
            if key.count != 16 {
                throw Error.config("AES-128 cipher key must be 16 bytes.")
            }
        case .aes256:
            if key.count != 32 {
                throw Error.config("AES-256 cipher key must be 32 bytes.")
            }
        default:
            break
        }

        self.init(method: method, defaultKey: key, defaultIV: iv)
    }
}
