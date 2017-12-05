import Foundation

/// A claim is a codable top-level property that can be verified against the current circumstances
///
/// Multiple claims form a payload
public protocol JWTClaim: Codable {
    /// The associated value type
    associatedtype Value: Codable

    /// The claim's value
    var value: Value { get set }

    /// Initializes the claim with its value.
    init(value: Value)
}

extension JWTClaim where Value == String, Self: ExpressibleByStringLiteral {
    /// See ExpressibleByStringLiteral.init
    public init(stringLiteral string: String) {
        self.init(value: string)
    }
}

extension JWTClaim {
    /// See Decodable.decode
    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        try self.init(value: single.decode(Value.self))
    }

    /// See Encodable.encode
    public func encode(to encoder: Encoder) throws {
        var single = encoder.singleValueContainer()
        try single.encode(value)
    }

}

/// Identifies by which application a Claim is issued
/// - id: iss
public struct IssuerClaim: JWTClaim, ExpressibleByStringLiteral {
    /// The identifier (or URI) of the issuer of the token
    public var value: String

    /// See Claim.init
    public init(value: String) {
        self.value = value
    }
}

/// Identifies the subject of a claim
/// such as the user in an authentication token
/// - id: sub
public struct SubjectClaim: JWTClaim, ExpressibleByStringLiteral {
    /// The claim's subject's identifier
    public var value: String

    /// See Claim.init
    public init(value: String) {
        self.value = value
    }
}

/// Identifies the destination application of the Claim
/// - id: aud
public struct AudienceClaim: JWTClaim, ExpressibleByStringLiteral {
    /// The identifier (or URI) of the destination application
    public var value: String

    /// See Claim.init
    public init(value: String) {
        self.value = value
    }
}

/// Identifies the date at which a Claim was issued
/// - id: iat
public struct IssuedAtClaim: JWTClaim {
    /// The `Date` at which this claim was issued
    public var value: Date

    /// See Claim.init
    public init(value: Date) {
        self.value = value
    }

}

/// Identifies the date at which a Claim was issued
/// - id: jti
public struct IDClaim: JWTClaim, ExpressibleByStringLiteral {
    /// A unique identifier for this claim
    public var value: String

    /// See Claim.init
    public init(value: String) {
        self.value = value
    }
}

