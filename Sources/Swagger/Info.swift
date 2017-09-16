import Foundation

public final class Info: Encodable {
    public var title: String
    public var description: String?
    public var termsOfService: String?
    public var contact: Contact?
    public var license: License?
    public let version = "3.0.0"
    
    init(named name: String) {
        self.title = name
    }
}

public struct Contact: Encodable {
    public var name: String
    public var url: URL
    public var email: String
    
    public init(name: String, url: URL, email: String) {
        self.name = name
        self.url = url
        self.email = email
    }
}

public struct License: Encodable, ExpressibleByStringLiteral {
    public var name: String
    public var url: URL?
    
    public init(stringLiteral value: String) {
        self.name = value
    }
}
