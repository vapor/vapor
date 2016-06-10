public struct Cookie {
    public var name: String
    public var value: String

    public var expires: String?
    public var maxAge: Int?
    public var domain: String?
    public var path: String?
    public var secure: Bool
    public var HTTPOnly: Bool

    public init(
        name: String,
        value: String,
        expires: String? = nil,
        maxAge: Int? = nil,
        domain: String? = nil,
        path: String? = nil,
        secure: Bool = false,
        HTTPOnly: Bool = false
    ) {
        self.name = name
        self.value = value
        self.expires = expires
        self.maxAge = maxAge
        self.domain = domain
        self.path = path
        self.secure = secure
        self.HTTPOnly = HTTPOnly
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
