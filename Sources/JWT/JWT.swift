import Foundation

/// A JWT is a Publically Readable set of claims
///
/// Each variable represents a claim
public protocol JWT: Codable {}

/// Identifies by which application a JWT is issued
public protocol IssuerClaim: JWT {
    /// The identifier (or URI) of the issuer of the token
    var iss: String { get }
}

/// Identifies the subject of a claim
///
/// Such as the user in an authentication token
public protocol SubjectClaim: JWT {
    /// The claim's subject's identifier
    var sub: String { get }
}

/// Identifies the destination application of the JWT
public protocol AudienceClaim: JWT {
    /// The identifier (or URI) of the destination application
    var aud: String { get }
}

/// Identifies the final date when a JWT becomes invalid
public protocol ExpirationClaim: JWT {
    /// The expiration `Date` of this token
    var exp: Date { get }
}

/// Identifies the first date at which a JWT becomes valid
public protocol NotBeforeClaim: JWT {
    /// The first `Date` at which this claim becomes valid
    var nbf: Date { get }
}

/// Identifies the date at which a JWT was issued
public protocol IssuedAtClaim: JWT {
    /// The `Date` at which this claim was issued
    var iat: Date { get }
}

/// Identifies the date at which a JWT was issued
public protocol IDClaim: JWT {
    /// A unique identifier for this claim
    var jti: String { get }
}
