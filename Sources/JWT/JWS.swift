import Crypto
import Foundation

fileprivate let jwsFields = ["typ", "cty", "alg", "jku", "jwk", "kid"]

/// Errors related to JWT
enum JWTError: Error {
    /// Happens when deserialization isn't possible according to spec
    case invalidJWS
    
    /// If the JOSE header is invalid
    ///
    /// Primarily when the critical fields array contains invalid fields
    case invalidJOSE
    
    /// If the signature validation reported an incorrect signature
    case invalidSignature
    
    /// An unsupported feature
    case unsupported
    
    case claimExpired
    
    case claimedTooSoon
    
    case invalidAudience
}

public struct JWTSigner {
    var secret: Data
    var identifier: String
    
    init(secret: Data, identifier: String) {
        self.secret = secret
        self.identifier = identifier
    }
    
    /// Signs the message and returns the UTF8 of this message
    ///
    /// Can be transformed into a String like so:
    ///
    /// ```swift
    /// let signed = try jws.sign()
    /// let signedString = String(bytes: signed, encoding: .utf8)
    /// ```
    public func signPayload<C: JWTPayload>(_ payload: C, using header: JWTHeader) throws -> Data {
        let headerData = try JSONEncoder().encode(header)
        let encodedHeader = Base64Encoder.encode(data: headerData)
        
        let payloadData = try JSONEncoder().encode(payload)
        let encodedPayload = Base64Encoder.encode(data: payloadData)
        
        let signature = try header.algorithm.sign(Data(encodedHeader + [0x2e] + encodedPayload), with: secret)
        let encodedSignature = Base64Encoder.encode(data: signature)
        
        return encodedHeader + [0x2e] + encodedPayload + [0x2e] + encodedSignature
    }
}

/// The header (details) used for signing and processing this JSON Web Signature
public struct JWTHeader: Codable {
    enum CodingKeys: String, CodingKey {
        case algorithm = "alg"
        case signatureType = "typ"
        case payloadType = "cty"
        case criticalFields = "crit"
    }
    
    /// The algorithm used with the signing
    public var algorithm: Algorithm
    
    /// The Signature's Content Type
    public var signatureType: String?
    
    /// The Payload's Content Type
    public var payloadType: String?
    
    public var criticalFields: [String]?
    
    /// The algorithm to use for signing
    public enum Algorithm: String, Codable {
        /// HMAC SHA256
        case HS256
        
        /// HMAC SHA384
        case HS384
        
        /// HMAC SHA512
        case HS512
        
        internal func sign(_ data: Data, with secret: Data) throws -> Data {
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
}

public struct JSONWebSignature<C: Codable>: Codable {
    /// The headers linked to this message
    ///
    /// A Web Token can be signed by multiple headers
    ///
    /// Currently we don't support anything other than 1 header
    private var headers: [Header]
    
    /// The JSON payload within this message
    public var payload: C
    
    /// The secret that is used by all authorized parties to sign messages
    private var secret: Data
    
    /// Signs the message and returns the UTF8 encoded String of this message
    public func signedString(_ header: Header? = nil) throws -> String {
        let signed = try sign(header)
        
        guard let string = String(bytes: signed, encoding: .utf8) else {
            throw JWTError.unsupported
        }
        
        return string
    }
    
    /// Signs the message and returns the UTF8 of this message
    ///
    /// Can be transformed into a String like so:
    ///
    /// ```swift
    /// let signed = try jws.sign()
    /// let signedString = String(bytes: signed, encoding: .utf8)
    /// ```
    public func sign(_ header: Header? = nil) throws -> Data {
        let usedHeader: Header
        
        if let header = header {
            usedHeader = header
        } else {
            guard let header = headers.first else {
                throw JWTError.unsupported
            }
            
            usedHeader = header
        }
        
        let headerData = try JSONEncoder().encode(usedHeader)
        let encodedHeader = Base64Encoder.encode(data: headerData)
        
        let payloadData = try JSONEncoder().encode(payload)
        let encodedPayload = Base64Encoder.encode(data: payloadData)
        
        let signature = try usedHeader.algorithm.sign(Data(encodedHeader + Data([0x2e]) + encodedPayload), with: secret)
        let encodedSignature = Base64Encoder.encode(data: signature)
        
        return encodedHeader + Data([0x2e]) + encodedPayload + Data([0x2e]) + encodedSignature
    }
    
    /// Creates a new JSON Web Signature from predefined data
    public init(headers: [Header], payload: C, secret: Data) {
        self.headers = headers
        self.payload = payload
        self.secret = secret
    }
    
    /// Parses a JWT String into a JSON Web Signature
    ///
    /// Verifies using the provided secret
    ///
    /// - throws: When the signature is invalid or the JWT is invalid
    public init(from string: String, verifiedWith signer: JWTSigner) throws {
        try self.init(from: Data(string.utf8), verifiedWith: signer)
    }
    
    /// Parses a JWT UTF8 String into a JSON Web Signature
    ///
    /// Verifies using the provided secret
    ///
    /// - throws: When the signature is invalid or the JWT is invalid
    public init(from data: Data, verifiedWith signer: JWTSigner) throws {
        let parts = data.split(separator: 0x2e)
        
        switch parts.count {
        case 3:
            let headerData = try Base64Decoder.decode(data: Data(parts[0]))
            let payloadData = try Base64Decoder.decode(data: Data(parts[1]))
            
            let header = try JSONDecoder().decode(JWTHeader.self, from: headerData)
            let payload = try JSONDecoder().decode(Self.self, from: payloadData)
            
            self = payload
            
            guard try signer.signPayload(self, using: header) == data else {
                throw JWTError.invalidSignature
            }
        default:
            throw JWTError.invalidJWS
        }
        
        try self.verify()
    }
}

extension JWTHeader {
    /// Creates a simple HMAC SHA256 header
    public static func hs256() -> JWTHeader {
        return JWTHeader(algorithm: .HS256, signatureType: nil, payloadType: nil, criticalFields: nil)
    }
    
    /// Creates a simple HMAC SHA384 header
    public static func hs384() -> JWTHeader {
        return JWTHeader(algorithm: .HS384, signatureType: nil, payloadType: nil, criticalFields: nil)
    }
    
    /// Creates a simple HMAC SHA512 header
    public static func hs512() -> JWTHeader {
        return JWTHeader(algorithm: .HS512, signatureType: nil, payloadType: nil, criticalFields: nil)
    }
}
