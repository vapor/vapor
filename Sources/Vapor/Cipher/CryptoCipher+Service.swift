import Crypto

extension CryptoCipher: Service {
    /// See Service.name
    public static var serviceName: String {
        return "crypto"
    }

    /// See Service.make()
    public static func makeService(for drop: Droplet) throws -> CryptoCipher? {
        guard let crypto = drop.config["crypto"] else {
            throw ConfigError.missingFile("crypto")
        }
        
        // Encoding
        guard let encodingString = crypto["cipher", "encoding"]?.string else {
            throw ConfigError.missing(
                key: ["cipher", "encoding"],
                file: "crypto",
                desiredType: String.self
            )
        }
        
        guard let encoding = try CryptoEncoding(encodingString) else {
            throw ConfigError.unsupported(
                value: encodingString,
                key: ["cipher", "encoding"],
                file: "crypto"
            )
        }
        
        guard let methodString = crypto["cipher", "method"]?.string else {
            throw ConfigError.missing(
                key: ["cipher", "method"],
                file: "crypto",
                desiredType: String.self
            )
        }
        
        let method: Cipher.Method
        switch methodString {
        case "aes128":
            method = .aes128(.cbc)
        case "aes256":
            method = .aes256(.cbc)
        default:
            if methodString == "chacha20" {
                print("Warning: chacha20 cipher is no longer available. Please use aes256 instead.")
            }
            throw ConfigError.unsupported(
                value: methodString,
                key: ["cipher", "method"],
                file: "crypto"
            )
        }
        
        guard let encodedKey = crypto["cipher", "key"]?.bytes else {
            throw ConfigError.missing(
                key: ["cipher", "key"],
                file: "crypto",
                desiredType: Bytes.self
            )
        }
        
        func openSSLInfo(_ log: LogProtocol) {
            log.info("Use `openssl rand -\(encoding) \(method.keyLength)` to generate a random string.")
        }
        
        let key = encoding.decode(encodedKey)
        if key.isAllZeroes {
            let log = try drop.make(LogProtocol.self)
            log.warning("The current cipher key \"\(encodedKey.makeString())\" is not secure.")
            log.warning("Update cipher.key in Config/crypto.json before using in production.")
            openSSLInfo(log)
        }
        
        guard method.keyLength == key.count else {
            let log = try drop.make(LogProtocol.self)
            log.error("\"\(encodedKey.makeString())\" decoded using \(encoding) is \(key.count) bytes.")
            log.error("\(method) cipher key must be \(method.keyLength) bytes.")
            openSSLInfo(log)
            throw ConfigError.unsupported(
                value: encodedKey.makeString(),
                key: ["cipher", "key"],
                file: "crypto"
            )
        }
        
        let encodedIV = crypto["cipher", "iv"]?.bytes
        
        let iv: Bytes?
        if let encodedIV = encodedIV {
            iv = encoding.decode(encodedIV)
        } else {
            iv = nil
        }
        
        if let iv = iv, let encodedIV = encodedIV {
            guard method.ivLength == iv.count else {
                let log = try drop.make(LogProtocol.self)
                log.error("\"\(encodedIV.makeString())\" decoded using \(encoding) is \(iv.count) bytes.")
                log.error("\(method) cipher iv must be \(method.ivLength) bytes.")
                openSSLInfo(log)
                throw ConfigError.unsupported(
                    value: encodedIV.makeString(),
                    key: ["cipher", "iv"],
                    file: "crypto"
                )
            }
        }
        
        return try .init(
            method: method,
            key: key,
            iv: iv,
            encoding: encoding
        )
    }
}

extension Array where Iterator.Element == Byte {
    internal var isAllZeroes: Bool {
        for i in self {
            if i != 0 {
                return false
            }
        }
        return true
    }
}
