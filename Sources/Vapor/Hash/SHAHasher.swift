import Essentials
import HMAC
import SHA2
import struct Core.Bytes

/**
    Create SHA + HMAC hashes with the
    Hash class by applying this driver.
*/
public class SHA2Hasher: Hash {
    /**
     Hashing variant to use
     */
    public enum Variant  {
        case sha224
        case sha256
        case sha384
        case sha512
    }

    public let variant: Variant

    /**
        HMAC key.
    */
    public let defaultKey: String?

    //
    private var keyBuffer: Bytes?

    /**
    */
    public init(variant: Variant, defaultKey: String?) {
        self.variant = variant
        self.defaultKey = defaultKey
        self.keyBuffer = defaultKey?.bytes
    }

    /**
        Hash given string with key

        - parameter message: message to hash
        - parameter key: key to hash with

        - returns: a hashed string
     */
    public func make(_ message: String, key: String?) throws -> String {
        let method: (auth: Method, hash: Essentials.Hash.Type)

        switch variant {
        case .sha224:
            method = (.sha224, SHA224.self)
        case .sha256:
            method = (.sha256, SHA256.self)
        case .sha384:
            method = (.sha384, SHA384.self)
        case .sha512:
            method = (.sha512, SHA512.self)
        }

        if let key = key {
            let hmac = HMAC(method.auth, message.bytes)
            return try hmac.authenticate(key: key.bytes).hexString
        } else {
            return try method.hash.init(message.bytes).hash().hexString
        }
    }

}
