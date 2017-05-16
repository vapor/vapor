/// Exhaustive list of methods
/// by which a message/hash can be encoded.
public enum CryptoEncoding {
    case hex
    case base64
    case plain
}

extension CryptoEncoding: StringInitializable {
    public init?(_ string: String) throws {
        switch string {
        case "hex":
            self = .hex
        case "base64":
            self = .base64
        case "plain":
            self = .plain
        default:
            return nil
        }
    }
}

extension CryptoEncoding {
    public func encode(_ bytes: Bytes) -> Bytes {
        switch self {
        case .base64:
            return bytes.base64Encoded
        case .hex:
            return bytes.hexEncoded
        case .plain:
            return bytes
        }
    }

    public func decode(_ bytes: Bytes) -> Bytes {
        switch self {
        case .base64:
            return bytes.base64Decoded
        case .hex:
            return bytes.hexDecoded
        case .plain:
            return bytes
        }
    }
}
