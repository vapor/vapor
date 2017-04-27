import Crypto
import Foundation
import CTLS

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

extension Cipher.Method {
    var keyLength: Int {
        return Int(EVP_CIPHER_key_length(evp))
    }
    
    var ivLength: Int {
        return Int(EVP_CIPHER_iv_length(evp))
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

        guard let encodedKey = crypto["cipher", "key"]?.bytes else {
            throw ConfigError.missing(
                key: ["cipher", "key"],
                file: "crypto",
                desiredType: Bytes.self
            )
        }
        
        func openSSLInfo(_ log: LogProtocol) {
            log.info("Use `openssl rand -\(encoding) \(method.keyLength)` to generate a random string.")
        }
        
        let key = encoding.decode(encodedKey)
        if key.allZeroes {
            let log = try config.resolveLog()
            log.warning("The current cipher key \"\(encodedKey.makeString())\" is not secure.")
            log.warning("Update cipher.key in Config/crypto.json before using in production.")
            openSSLInfo(log)
        }
        
        guard method.keyLength == key.count else {
            let log = try config.resolveLog()
            log.error("\"\(encodedKey.makeString())\" decoded using \(encoding) is \(key.count) bytes.")
            log.error("\(method) cipher key must be \(method.keyLength) bytes.")
            openSSLInfo(log)
            throw ConfigError.unsupported(
                value: encodedKey.makeString(),
                key: ["cipher", "key"],
                file: "crypto"
            )
        }

        let encodedIV = crypto["cipher", "iv"]?.bytes
        
        let iv: Bytes?
        if let encodedIV = encodedIV {
            iv = encoding.decode(encodedIV)
        } else {
            iv = nil
        }
        
        if let iv = iv, let encodedIV = encodedIV {
            guard method.ivLength == iv.count else {
                let log = try config.resolveLog()
                log.error("\"\(encodedIV.makeString())\" decoded using \(encoding) is \(iv.count) bytes.")
                log.error("\(method) cipher iv must be \(method.ivLength) bytes.")
                openSSLInfo(log)
                throw ConfigError.unsupported(
                    value: encodedIV.makeString(),
                    key: ["cipher", "iv"],
                    file: "crypto"
                )
            }
        }

        try self.init(
            method: method,
            key: key,
            iv: iv,
            encoding: encoding
        )
    }
}

extension Array where Iterator.Element == Byte {
    var allZeroes: Bool {
        for i in self {
            if i != 0 {
                return false
            }
        }
        return true
    }
}
