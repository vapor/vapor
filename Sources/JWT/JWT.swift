import Bits
import Crypto
import Foundation

/// A JSON Web Token
public struct JWT<Payload> where Payload: JWTPayload {
    /// The headers linked to this message
    public var header: JWTHeader

    /// The JSON payload within this message
    public var payload: Payload

    /// Creates a new JSON Web Signature from predefined data
    public init(header: JWTHeader = .init(), payload: Payload) {
        self.header = header
        self.payload = payload
    }

    /// Parses a JWT string into a JSON Web Token
    public init(from string: String, verifiedUsing signer: JWTSigner) throws {
        try self.init(from: Data(string.utf8), verifiedUsing: signer)
    }

    /// Parses a JWT string into a JSON Web Signature
    public init(from string: String, verifiedUsing signers: JWTSigners) throws {
        try self.init(from: Data(string.utf8), verifiedUsing: signers)
    }

    /// Parses a JWT string into a JSON Web Signature
    public init(from data: Data, verifiedUsing signer: JWTSigner) throws {
        let parts = data.split(separator: .period)
        guard parts.count == 3 else {
            throw JWTError(identifier: "invalidJWT", reason: "Malformed JWT")
        }

        let headerData = Data(parts[0])
        let payloadData = Data(parts[1])
        let signatureData = Data(parts[2])

        guard try signer.signature(header: headerData, payload: payloadData) == signatureData else {
            throw JWTError(identifier: "invalidSignature", reason: "Invalid JWT signature")
        }

        let base64 = Base64Decoder(encoding: .base64url)
        self.header = try JSONDecoder().decode(JWTHeader.self, from:  base64.decode(data: headerData))
        self.payload = try JSONDecoder().decode(Payload.self, from: base64.decode(data: payloadData))
        try payload.verify()
    }

    /// Parses a JWT string into a JSON Web Signature
    public init(from data: Data, verifiedUsing signers: JWTSigners) throws {
        let parts = data.split(separator: .period)
        guard parts.count == 3 else {
            throw JWTError(identifier: "invalidJWT", reason: "Malformed JWT")
        }

        let headerData = Data(parts[0])
        let payloadData = Data(parts[1])
        let signatureData = Data(parts[2])

        let base64 = Base64Decoder(encoding: .base64url)
        let header = try JSONDecoder().decode(JWTHeader.self, from:  base64.decode(data: headerData))
        guard let kid = header.kid else {
            throw JWTError(identifier: "missingKID", reason: "`kid` header property required to identify signer")
        }

        let signer = try signers.requireSigner(kid: kid)
        guard try signer.signature(header: headerData, payload: payloadData) == signatureData else {
            throw JWTError(identifier: "invalidSignature", reason: "Invalid JWT signature")
        }

        self.header = header
        self.payload = try JSONDecoder().decode(Payload.self, from: base64.decode(data: payloadData))
        try payload.verify()
    }

    /// Parses a JWT string into a JSON Web Signature
    public init(unverifiedFrom data: Data) throws {
        let parts = data.split(separator: .period)
        guard parts.count == 3 else {
            throw JWTError(identifier: "invalidJWT", reason: "Malformed JWT")
        }

        let headerData = Data(parts[0])
        let payloadData = Data(parts[1])

        let base64 = Base64Decoder(encoding: .base64url)
        self.header = try JSONDecoder().decode(JWTHeader.self, from:  base64.decode(data: headerData))
        self.payload = try JSONDecoder().decode(Payload.self, from: base64.decode(data: payloadData))
    }

    /// Signs the message and returns the serialized JSON web token
    public mutating func sign(using signers: JWTSigners) throws -> Data {
        guard let kid = header.kid else {
            throw JWTError(identifier: "missingKID", reason: "`kid` header property required to identify signer")
        }

        let signer = try signers.requireSigner(kid: kid)
        return try signer.sign(&self)
    }

    /// Signs the message and returns the serialized JSON web token
    public mutating func sign(using signer: JWTSigner) throws -> Data {
        return try signer.sign(&self)
    }
}
