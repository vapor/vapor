import Cipher
import Core
import Essentials
import Foundation

public final class CryptoCipher: CipherProtocol {
    public let method: Cipher.Method

    public var defaultKey: Bytes
    public var defaultIV: Bytes?

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
