import HMAC
import SHA1

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

        let hmac = HMAC.authenticate(key: keyBuff, message: msgBuff, variant: SHA1.self)
        return hmac.toHexString()
    }

}
