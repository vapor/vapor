/**
    Create SHA256 + HMAC hashes with the
    Hash class by applying this driver.
*/
public class SHA256Hasher: HashDriver {

    public func hash(message: String, key: String) -> String {

        var msgBuff = [UInt8]()
        msgBuff += message.utf8

        var keyBuff = [UInt8]()
        keyBuff += key.utf8

        if let hmac = HMAC.authenticate(key: keyBuff, message: msgBuff) {
            return hmac.toHexString()
        } else {
            Log.error("Unable to create hash, returning hash for empty string.")
            return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }

    }

}
