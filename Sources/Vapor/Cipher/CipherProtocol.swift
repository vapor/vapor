public protocol CipherProtocol {
    var defaultKey: Bytes { get }
    var defaultIV: Bytes? { get }
    func encrypt(_ bytes: Bytes, key: Bytes, iv: Bytes?) throws -> Bytes
    func decrypt(_ bytes: Bytes, key: Bytes, iv: Bytes?) throws -> Bytes
}

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

public enum CipherEncoding {
    case hex
    case base64
}

extension CipherProtocol {
    public func encrypt(_ bytes: Bytes, key: Bytes? = nil) throws -> Bytes {
        return try encrypt(bytes, key: key ?? defaultKey, iv: defaultIV)
    }

    public func encrypt(_ string: String, key: Bytes? = nil, encoding: CipherEncoding = .base64) throws -> String {
        let m = try encrypt(string.bytes, key: key)
        switch encoding {
        case .hex:
            return m.hexString
        case .base64:
            return m.base64String
        }
    }
}

extension CipherProtocol {
    public func decrypt(_ bytes: Bytes, key: Bytes? = nil) throws -> Bytes {
        return try decrypt(bytes, key: key ?? defaultKey, iv: defaultIV)
    }

    public func decrypt(_ string: String, key: Bytes? = nil, encoding: CipherEncoding = .base64) throws -> String {
        let bytes: Bytes

        switch encoding {
        case .hex:
            var data = Bytes()

            var gen = string.characters.makeIterator()
            while let c1 = gen.next(), let c2 = gen.next() {
                let s = String([c1, c2])

                guard let d = Byte(s, radix: 16) else {
                    break
                }

                data.append(d)
            }
            bytes = data
        case .base64:
            bytes = string.base64Decoded
        }

        let d = try decrypt(bytes, key: key)
        return d.string
    }
}

extension String {
    public var base64Decoded: Bytes {
        guard let data = NSData(base64Encoded: self, options: []) else { return [] }
        var bytes = Bytes(repeating: 0, count: data.length)
        data.getBytes(&bytes,  length: data.length)
        return bytes
    }
}

