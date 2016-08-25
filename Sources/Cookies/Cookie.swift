import Core
import Foundation

/**
    Represents an HTTP Cookie as described
    in HTTP State Management Mechanism (RFC 6265)
*/
public struct Cookie {
    public var name: String
    public var value: String

    public var expires: Date?
    public var maxAge: Int?
    public var domain: String?
    public var path: String?
    public var secure: Bool
    public var httpOnly: Bool

    public init(
        name: String,
        value: String,
        expires: Date? = nil,
        maxAge: Int? = nil,
        domain: String? = nil,
        path: String? = "/",
        secure: Bool = false,
        httpOnly: Bool = false
    ) {
        self.name = name
        self.value = value
        self.expires = expires
        self.maxAge = maxAge
        self.domain = domain
        self.path = path
        self.secure = secure
        self.httpOnly = httpOnly
    }
}

extension Cookie: Hashable, Equatable {
    public var hashValue: Int {
        return name.hashValue
    }
}

public func ==(lhs: Cookie, rhs: Cookie) -> Bool {
    return lhs.name == rhs.name
}
