import Crypto
import Foundation

/// The algorithm to use for signing
public protocol JWTAlgorithm {
    var jwtAlgorithmName: String { get }
    func makeCiphertext(from plaintext: Data) throws -> Data
}

public struct HMACAlgorithm: JWTAlgorithm {
    /// HMAC variant to use
    public let variant: HMACAlgorithmVariant

    /// The HMAC key
    public let key: Data

    /// See JWTAlgorithm.jwtAlgorithmName
    public var jwtAlgorithmName: String {
        switch variant {
        case .sha256: return "HS256"
        case .sha384: return "HS384"
        case .sha512: return "HS512"
        }
    }

    /// Create a new HMAC algorithm
    public init(_ variant: HMACAlgorithmVariant, key: Data) {
        self.variant = variant
        self.key = key
    }

    /// See JWTAlgorithm.makeCiphertext
    public func makeCiphertext(from plaintext: Data) throws -> Data {
        switch variant {
        case .sha256: return HMAC<SHA256>.authenticate(plaintext, withKey: key)
        case .sha384: return HMAC<SHA384>.authenticate(plaintext, withKey: key)
        case .sha512: return HMAC<SHA512>.authenticate(plaintext, withKey: key)
        }
    }
}

/// Supported HMAC algorithm variants
public enum HMACAlgorithmVariant {
    case sha256
    case sha384
    case sha512
}
