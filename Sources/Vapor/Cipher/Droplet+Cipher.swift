extension Droplet {
    func verifyCipher() {
        // verify cipher
        if let c = cipher as? CryptoCipher {
            switch c.method {
            case .chacha20:
                if c.defaultKey.count != 32 {
                    log.error("Chacha20 cipher key must be 32 bytes.")
                }
                if c.defaultIV == nil {
                    log.error("Chacha20 cipher requires an initialization vector (iv).")
                } else if c.defaultIV?.count != 8 {
                    log.error("Chacha20 initialization vector (iv) must be 8 bytes.")
                }
            case .aes128:
                if c.defaultKey.count != 16 {
                    log.error("AES-128 cipher key must be 16 bytes.")
                }
            case .aes256:
                if c.defaultKey.count != 16 {
                    log.error("AES-256 cipher key must be 16 bytes.")
                }
            default:
                log.warning("Using unofficial cipher, ensure key and possibly initialization vector (iv) are set properly.")
                break
            }
        }
    }
}
