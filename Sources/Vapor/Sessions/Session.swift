///// Something that is convertible between a Cookie and an instance.
//public final class Session {
//    /// The cookie value
//    public var cookie: Cookie.Value?
//
//    /// This session's data
//    public var data: SessionData
//
//    /// Create a new session.
//    public init(cookie: Cookie.Value? = nil, data: SessionData = .init()) {
//        self.cookie = cookie
//        self.data = data
//    }
//}
//
///// Codable session data.
//public struct SessionData: Codable {
//    /// Session codable object storage.
//    internal var storage: [String: String]
//
//    /// Create a new, empty session data.
//    public init() {
//        storage = [:]
//    }
//
//    /// See Decodable.init
//    public init(from decoder: Decoder) throws {
//        storage = try [String: String].init(from: decoder)
//    }
//
//    /// See Encodable.encode
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: String.self)
//        for (key, val) in storage {
//            try container.encode(val, forKey: key)
//        }
//    }
//}
//
//extension Session {
//    /// Convenience [String: String] accessor.
//    public subscript(_ key: String) -> String? {
//        get {
//            return data.storage[key]
//        }
//        set {
//            data.storage[key] = newValue
//        }
//    }
//}
//
//extension String: CodingKey {
//    public var stringValue: String {
//        return self
//    }
//
//    public var intValue: Int? {
//        return Int(self)
//    }
//
//    public init?(stringValue: String) {
//        self = stringValue
//    }
//
//    public init?(intValue: Int) {
//        self = intValue.description
//    }
//}

