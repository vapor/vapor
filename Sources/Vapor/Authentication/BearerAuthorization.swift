/// A bearer token.
public struct BearerAuthorization {
    /// The plaintext token
    public let token: String

    /// Create a new `BearerAuthorization`
    public init(token: String) {
        self.token = token
    }
}

extension HTTPHeaders {
    /// Access or set the `Authorization: Bearer: ...` header.
    public var bearerAuthorization: BearerAuthorization? {
        get {
            guard let string = self.firstValue(name: .authorization) else {
                return nil
            }

            guard let range = string.range(of: "Bearer ") else {
                return nil
            }

            let token = string[range.upperBound...]
            return .init(token: String(token))
        }
        set {
            if let bearer = newValue {
                replaceOrAdd(name: .authorization, value: "Bearer \(bearer.token)")
            } else {
                remove(name: .authorization)
            }
        }
    }
}
