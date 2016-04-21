import HMAC
import SHA2

/**
    Create SHA + HMAC hashes with the
    Hash class by applying this driver.
*/
public class SHA2Hasher: HashDriver {

    var variant: Variant

    init(variant: Variant) {
        self.variant = variant
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
        Hash given string with key

        - parameter message: message to hash
        - parameter key: key to hash with

        - returns: a hashed string
     */
    public func hash(_ message: String, key: String) -> String {
        let keyBuff = key.data.bytes
        let msgBuff = message.data.bytes

        let hashed: [Byte]

        switch variant {
        case .sha256:
            hashed = HMAC<SHA2<SHA256>>.authenticate(message: msgBuff, withKey: keyBuff)
        case .sha384:
            hashed = HMAC<SHA2<SHA384>>.authenticate(message: msgBuff, withKey: keyBuff)
        case .sha512:
            hashed = HMAC<SHA2<SHA512>>.authenticate(message: msgBuff, withKey: keyBuff)
        }

        return hashed.hexString
    }

}
