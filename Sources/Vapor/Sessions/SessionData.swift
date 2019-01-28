/// Codable session data.
public struct SessionData: Codable {
    /// Session codable object storage.
    internal var storage: [String: String]

    /// Create a new, empty session data.
    public init() {
        self.storage = [:]
    }

    /// See `Decodable`.
    public init(from decoder: Decoder) throws {
        self.storage = try .init(from: decoder)
    }

    /// See `Encodable`.
    public func encode(to encoder: Encoder) throws {
        try self.storage.encode(to: encoder)
    }
    
    /// Convenience `[String: String]` accessor.
    public subscript(_ key: String) -> String? {
        get { return self.storage[key] }
        set { self.storage[key] = newValue }
    }
}
