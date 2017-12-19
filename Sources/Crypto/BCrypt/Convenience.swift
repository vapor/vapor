import Foundation

// MARK: Serializer

extension BCrypt {
    public static func make(message: Data, with salt: Salt? = nil) throws -> Data {
        let hash = try BCrypt(salt)
        var message = message
        
        let digest = hash.digest(message: &message)
        let serializer = Serializer(hash.salt, digest: digest)
        return serializer.serialize()
    }

    public static func make(message: String, with salt: Salt? = nil) throws -> Data {
        return try make(
            message: Data(message.utf8),
            with: salt
        )
    }
}

// MARK: Parser

extension BCrypt {
    public static func verify(message: Data, matches input: Data) throws -> Bool {
        let parser = try Parser(input)
        var message = message
        
        let salt = try parser.parseSalt()
        let hasher = try BCrypt(salt)
        let testDigest = hasher.digest(message: &message)
        return try testDigest == parser.parseDigest()
    }

    public static func verify(message: String, matches digest: String) throws -> Bool {
        return try verify(
            message: Data(message.utf8),
            matches: Data(digest.utf8)
        )
    }

    public static func verify(message: Data, matches digest: String) throws -> Bool {
        return try verify(
            message: message,
            matches: Data(digest.utf8)
        )
    }

    public static func verify(message: String, matches digest: Data) throws -> Bool {
        return try verify(
            message: Data(message.utf8),
            matches: digest
        )
    }
}
