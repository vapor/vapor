import Crypto
import Foundation

/// Encrypt and decrypt messages using
/// OpenSSL ciphers.
public final class CryptoCipher: CipherProtocol {
    /// The specified Cipher
    public let cipher: Cipher

    /// The encoding used to format
    /// encrypted bytes.
    public let encoding: CryptoEncoding

    /// Creates a CryptoCipher
    public init(
        method: Cipher.Method,
        key: Bytes,
        iv: Bytes? = nil,
        encoding: CryptoEncoding
    ) throws {
        self.cipher = try Cipher(method, key: key, iv: iv)
        self.encoding = encoding
    }

    /// Encrypts a message
    public func encrypt(_ bytes: Bytes) throws -> Bytes {
        let encrypted = try cipher.encrypt(bytes)
        return encoding.encode(encrypted)
    }

    /// Decrypts a message
    public func decrypt(_ bytes: Bytes) throws -> Bytes {
        let decoded = encoding.decode(bytes)
        return try cipher.decrypt(decoded)
    }
}

extension CryptoCipher: ConfigInitializable {
    public convenience init(config: Configs.Config) throws {
        guard let crypto = config["crypto"] else {
            throw ConfigError.missingFile("crypto")
        }


        // Encoding
        guard let encodingString = crypto["cipher", "encoding"]?.string else {
            throw ConfigError.missing(
                key: ["cipher", "encoding"],
                file: "crypto",
                desiredType: String.self
            )
        }

        guard let encoding = try CryptoEncoding(encodingString) else {
            throw ConfigError.unsupported(
                value: encodingString,
                key: ["cipher", "encoding"],
                file: "crypto"
            )
        }

        guard let methodString = crypto["cipher", "method"]?.string else {
            throw ConfigError.missing(
                key: ["cipher", "method"],
                file: "crypto",
                desiredType: String.self
            )
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
            throw ConfigError.unsupported(
                value: methodString,
                key: ["cipher", "method"],
                file: "crypto"
            )
        }

        guard let key = config["crypto", "cipher", "key"]?.bytes else {
            throw ConfigError.missing(
                key: ["cipher", "key"],
                file: "crypto",
                desiredType: Bytes.self
            )
        }

        let keyString = key.makeString()
        if keyString.contains("password") {
            let log = try config.resolveLog()
            log.warning("The current cipher key \"\(keyString)\" is not secure.")
            log.warning("Update cipher.key in Config/crypto.json before using in production.")
            log.info("Use `openssl rand -base64 <length>` to generate a random string.")
        }

        let iv = config["crypto", "cipher", "iv"]?.string?.makeBytes()

        switch method {
        case .aes128:
            if key.count != 16 {
                print("AES-126 cipher key must be 16 bytes")
                throw ConfigError.unsupported(
                    value: keyString,
                    key: ["cipher", "key"],
                    file: "crypto"
                )
            }
        case .aes256:
            if key.count != 32 {
                print("AES-256 cipher key must be 32 bytes.")
                throw ConfigError.unsupported(
                    value: keyString,
                    key: ["cipher", "key"],
                    file: "crypto"
                )
            }
        default:
            break
        }

        try self.init(
            method: method,
            key: key,
            iv: iv,
            encoding: encoding
        )
    }
}
