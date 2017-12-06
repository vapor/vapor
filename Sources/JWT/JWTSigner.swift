import Crypto
import Foundation

/// A JWT signer.
public final class JWTSigner {
    /// Algorithm
    public var algorithm: JWTAlgorithm

    /// Base64 encoder
    private let base64: Base64Encoder

    /// Create a new JWT signer.
    public init(algorithm: JWTAlgorithm) {
        self.algorithm = algorithm
        self.base64 = Base64Encoder(encoding: .base64url)
    }

    /// Signs the message and returns the UTF8 of this message
    ///
    /// Can be transformed into a String like so:
    ///
    /// ```swift
    /// let signed = try jws.sign()
    /// let signedString = String(bytes: signed, encoding: .utf8)
    /// ```
    public func sign<Payload>(_ jwt: inout JWT<Payload>) throws -> Data {
        jwt.header.alg = self.algorithm.jwtAlgorithmName
        let headerData = try JSONEncoder().encode(jwt.header)
        let encodedHeader = base64.encode(data: headerData)

        let payloadData = try JSONEncoder().encode(jwt.payload)
        let encodedPayload = base64.encode(data: payloadData)

        let encodedSignature = try signature(header: encodedHeader, payload: encodedPayload)
        return encodedHeader + Data([.period]) + encodedPayload + Data([.period]) + encodedSignature
    }

    /// Generates a signature for the supplied payload and header.
    public func signature(header: Data, payload: Data) throws -> Data {
        let message: Data = header + Data([.period]) + payload
        let signature = try algorithm.makeCiphertext(from: message)
        return base64.encode(data: signature)
    }
}

extension JWTSigner {
    /// Creates an HS256 JWT signer with the supplied key
    public static func hs256(key: Data) -> JWTSigner {
        return JWTSigner(algorithm: HMACAlgorithm(.sha256, key: key))
    }

    /// Creates an HS384 JWT signer with the supplied key
    public static func hs384(key: Data) -> JWTSigner {
        return JWTSigner(algorithm: HMACAlgorithm(.sha384, key: key))
    }

    /// Creates an HS512 JWT signer with the supplied key
    public static func hs512(key: Data) -> JWTSigner {
        return JWTSigner(algorithm: HMACAlgorithm(.sha512, key: key))
    }
}
