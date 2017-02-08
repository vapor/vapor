/**
    Hash strings using the static methods on this class.
*/
public protocol HashProtocol {
    /**
         A string used to add an additional
         layer of security to all hashes
    */
    var defaultKey: Bytes? { get }

    /**
         Given a string, this function will
         return the hashed string according
         to whatever algorithm it chooses to implement.
    */
    func make(_ string: Bytes, key: Bytes?) throws -> Bytes
}

public enum HashEncoding {
    case hex
    case base64
}

extension HashProtocol {
    public func make(_ string: String, key: String?, encoding: HashEncoding = .hex) throws -> String {
        let hash = try make(string.bytes, key: key?.bytes)

        switch encoding {
        case .hex:
            return hash.hexString
        case .base64:
            return hash.base64Encoded.string
        }
    }

    public func make(_ string: String, encoding: HashEncoding = .hex) throws -> String {
        return try make(string, key: defaultKey?.string, encoding: encoding)
    }
}
