import HMAC
import SHA2
import struct Core.Bytes

/**
    Create SHA + HMAC hashes with the
    Hash class by applying this driver.
*/
public class SHA2Hasher: Hash {

    var variant: Variant

    init(variant: Variant) {
        self.variant = variant
        self.key = ""
        self.keyBuffer = []
    }

    /**
        Hashing variant to use
     */
    public enum Variant  {
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
        let msgBuff = message.bytes

        let hashed: Bytes

        switch variant {
        case .sha256:
            hashed = HMAC<SHA2<SHA256>>.authenticate(message: msgBuff, withKey: keyBuffer)
        case .sha384:
            hashed = HMAC<SHA2<SHA384>>.authenticate(message: msgBuff, withKey: keyBuffer)
        case .sha512:
            hashed = HMAC<SHA2<SHA512>>.authenticate(message: msgBuff, withKey: keyBuffer)
        }

        return hashed.hexString
    }

}
