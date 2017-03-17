import Foundation

/**
    Objects conforming to this protocol can be
    used as ciphers for encrypting and decrypting information.
*/
public protocol CipherProtocol {
    /**
        The default key will be used
        if not encryption or decryption
        key is specified (for protocol extensions).
    */
    var defaultKey: Bytes { get }

    /**
        The default initialization (iv) vector
        will be used if not other iv is specified.
    */
    var defaultIV: Bytes? { get }

    /**
        Encrypts bytes with a required key and
        optional initialization vector.
    */
    func encrypt(_ bytes: Bytes, key: Bytes, iv: Bytes?) throws -> Bytes

    /**
        Decrypts bytes with a required key and
        optional initialization vector.
    */
    func decrypt(_ bytes: Bytes, key: Bytes, iv: Bytes?) throws -> Bytes
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
        let m = try encrypt(string.makeBytes(), key: key)
        switch encoding {
        case .hex:
            return m.hexString
        case .base64:
            return m.base64Encoded.makeString()
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
        return d.makeString()
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

