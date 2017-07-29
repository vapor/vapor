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
