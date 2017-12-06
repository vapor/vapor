import Foundation

/// A JWT payload is a Publically Readable set of claims
///
/// Each variable represents a claim
public protocol JWTPayload: Codable, JWTVerifiable { }
