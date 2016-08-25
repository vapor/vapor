import HMAC
import SHA2
import struct Core.Bytes

/**
    Create SHA + HMAC hashes with the
    Hash class by applying this driver.
*/
public class SHA2Hasher: Hash {

    public let variant: Variant

    public init(variant: Variant) {
        self.variant = variant
        self.keyBuffer = []
    }

    /**
        Hashing variant to use
     */
    public enum Variant  {
        case sha224
        case sha256
        case sha384
        case sha512
    }

    /**
        HMAC key.
    */
    public var key: String {
        didSet {
            keyBuffer = key.bytes
        }
    }

    //
    private var keyBuffer: Bytes

    /**
        Hash given string with key

        - parameter message: message to hash
        - parameter key: key to hash with

        - returns: a hashed string
     */
    public func make(_ message: String) -> String {
        let auth: Authenticatable.Type

        switch variant {
        case .sha224:
            auth = SHA224.self
        case .sha256:
            auth = SHA256.self
        case .sha384:
            auth = SHA384.self
        case .sha512:
            auth = SHA512.self
        }

        return HMAC(auth, message.bytes).authenticate(key: keyBuffer).hexString
    }

}
