import Foundation

/// Claims that should be verified
public protocol JWTVerifiable {
    /// Verifies the claim or payload is correct or throws an error
    func verify() throws
}

/// Identifies the final date when a Claim becomes invalid
/// - id: exp
public struct ExpirationClaim: JWTClaim, JWTVerifiable {
    /// The expiration `Date` of this token
    public var value: Date

    /// See Claim.init
    public init(value: Date) {
        self.value = value
    }

    /// See Claim.verify
    public func verify() throws {
        switch value.compare(Date()) {
        case .orderedAscending, .orderedSame: throw JWTError(identifier: "exp", reason: "Expiration claim failed")
        case .orderedDescending: break
        }
    }
}

/// Identifies the first date at which a Claim becomes valid
/// - id: nbf
public struct NotBeforeClaim: JWTClaim, JWTVerifiable {
    /// The first `Date` at which this claim becomes valid
    public var value: Date

    /// See Claim.init
    public init(value: Date) {
        self.value = value
    }

    /// See Claim.verify
    public func verify() throws {
        switch value.compare(Date()) {
        case .orderedDescending: throw JWTError(identifier: "nbf", reason: "Not before claim failed")
        case .orderedAscending, .orderedSame: break
        }
    }
}
