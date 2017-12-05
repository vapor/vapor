import Crypto
import Foundation

/// The algorithm to use for signing
public enum JWTAlgorithm: String, Codable {
    /// HMAC SHA256
    case HS256

    /// HMAC SHA384
    case HS384

    /// HMAC SHA512
    case HS512

    public func sign(_ data: Data, with secret: Data) throws -> Data {
        switch self {
        case .HS256:
            return HMAC<SHA256>.authenticate(data, withKey: secret)
        case .HS384:
            return HMAC<SHA384>.authenticate(data, withKey: secret)
        case .HS512:
            return HMAC<SHA512>.authenticate(data, withKey: secret)
        }
    }
}
