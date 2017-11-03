import Foundation

/// A JWT is a Publically Readable set of claims
///
/// Each variable represents a claim
public protocol JWTPayload: Codable {
    func verify() throws
}

/// A claim is a codable top-level property that can be verified against the current circumstances
///
/// Multiple claims form a payload
public protocol Claim: Codable {}

/// Identifies by which application a Claim is issued
public protocol IssuerClaim: Claim {
    /// The identifier (or URI) of the issuer of the token
    var iss: String { get }
}

/// Identifies the subject of a claim
///
/// Such as the user in an authentication token
public protocol SubjectClaim: Claim {
    /// The claim's subject's identifier
    var sub: String { get }
}

/// Identifies the destination application of the Claim
public protocol AudienceClaim: Claim {
    /// The identifier (or URI) of the destination application
    var aud: String { get }
}

/// Identifies the final date when a Claim becomes invalid
public protocol ExpirationClaim: Claim {
    /// The expiration `Date` of this token
    var exp: Date { get }
}

/// Identifies the first date at which a Claim becomes valid
public protocol NotBeforeClaim: Claim {
    /// The first `Date` at which this claim becomes valid
    var nbf: Date { get }
}

/// Identifies the date at which a Claim was issued
public protocol IssuedAtClaim: Claim {
    /// The `Date` at which this claim was issued
    var iat: Date { get }
}

/// Identifies the date at which a Claim was issued
public protocol IDClaim: Claim {
    /// A unique identifier for this claim
    var jti: String { get }
}
