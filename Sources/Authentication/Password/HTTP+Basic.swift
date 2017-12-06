import Bits
import Crypto
import HTTP

extension HTTPHeaders {
    /// Access or set the `Authorization: Basic: ...` header.
    public var basicAuthorization: Password? {
        get {
            guard let string = self[.authorization] else {
                return nil
            }

            guard let range = string.range(of: "Basic ") else {
                return nil
            }

            let token = string[range.upperBound...]
            guard let decodedToken = try? Base64Decoder().decode(string: String(token)) else {
                return nil
            }

            let parts = decodedToken.split(separator: .colon)

            guard parts.count == 2 else {
                return nil
            }

            guard
                let username = String(data: parts[0], encoding: .utf8),
                let password = String(data: parts[1], encoding: .utf8)
            else {
                return nil
            }

            return Password(username: username, password: password)
        }
        set {
            if let basic = newValue {
                let credentials = "\(basic.username):\(basic.password)"
                let encoded = Base64Encoder().encode(string: credentials)
                self[.authorization] = "Basic \(encoded)"
            } else {
                self[.authorization] = nil
            }
        }
    }
}
