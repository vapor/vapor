import Foundation

/// The header (details) used for signing and processing this JSON Web Signature
public struct JWTHeader: Codable {
    /// The algorithm used with the signing
    public var alg: String?
    
    /// The Signature's Content Type
    public var typ: String?
    
    /// The Payload's Content Type
    public var cty: String?

    /// Critical fields
    public var crit: [String]?

    /// The JWT key identifier
    public var kid: String?

    /// Create a new JWT header
    public init(
        alg: String? = nil,
        typ: String? = "JWT",
        cty: String? = nil,
        crit: [String]? = nil,
        kid: String? = nil
    ) {
        self.alg = alg
        self.typ = typ
        self.cty = cty
        self.crit = crit
        self.kid = kid
    }
}
