import HTTPTypes

/// A bearer token.
public struct BearerAuthorization: Sendable {
    /// The plaintext token
    public let token: String

    /// Create a new `BearerAuthorization`
    public init(token: String) {
        self.token = token
    }
}

extension HTTPFields {
    /// Access or set the `Authorization: Bearer: ...` header.
    public var bearerAuthorization: BearerAuthorization? {
        get {
            guard let string = self[.authorization] else {
                return nil
            }

            let headerParts = string.split(separator: " ")
            guard headerParts.count == 2 else {
                return nil
            }
            guard headerParts[0].lowercased() == "bearer" else {
                return nil
            }
            return .init(token: String(headerParts[1]))
        }
        set {
            if let bearer = newValue {
                self[.authorization] = "Bearer \(bearer.token)"
            } else {
                self[.authorization] = nil
            }
        }
    }
}
