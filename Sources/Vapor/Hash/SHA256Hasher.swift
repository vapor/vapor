import CryptoKitten

/**
    Create SHA1 + HMAC hashes with the
    Hash class by applying this driver.
*/
public class SHAHasher: HashDriver {

    public func hash(message: String, key: String) -> String {

        var msgBuff = [UInt8]()
        msgBuff += message.utf8

        var keyBuff = [UInt8]()
        keyBuff += key.utf8

        if let hmac = HMAC.authenticate(key: keyBuff, message: msgBuff, variant: .sha1) {
            return hmac.toHexString()
        } else {
            Log.error("Unable to create hash, returning hash for empty string.")
            return "da39a3ee5e6b4b0d3255bfef95601890afd80709"
        }

    }

}
