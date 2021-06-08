/// A basic username and password.
public struct BasicAuthorization {
    /// The username, sometimes an email address
    public let username: String

    /// The plaintext password
    public let password: String

    /// Create a new `BasicAuthorization`.
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

extension HTTPHeaders {
    /// Access or set the `Authorization: Basic: ...` header.
    public var basicAuthorization: BasicAuthorization? {
        get {
            guard let string = self.first(name: .authorization) else {
                return nil
            }

            let headerParts = string.split(separator: " ")
            guard headerParts.count == 2 else {
                return nil
            }
            guard headerParts[0] == "Basic" else {
                return nil
            }
            guard let decodedToken = Data(base64Encoded: .init(headerParts[1])) else {
                return nil
            }
            let parts = String.init(decoding: decodedToken, as: UTF8.self).split(separator: ":", maxSplits: 1)

            guard parts.count == 2 else {
                return nil
            }

            return .init(username: .init(parts[0]), password: .init(parts[1]))
        }
        set {
            if let basic = newValue {
                let credentials = "\(basic.username):\(basic.password)"
                let encoded = Data(credentials.utf8).base64EncodedString()
                replaceOrAdd(name: .authorization, value: "Basic \(encoded)")
            } else {
                remove(name: .authorization)
            }
        }
    }
}
