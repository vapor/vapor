/// Codable session data.
public struct SessionData: Codable {
    /// Session codable object storage.
    internal var storage: [String: String]

    /// Create a new, empty session data.
    public init() {
        storage = [:]
    }

    /// See `Decodable`.
    public init(from decoder: Decoder) throws {
        storage = try .init(from: decoder)
    }

    /// See `Encodable`.
    public func encode(to encoder: Encoder) throws {
        try storage.encode(to: encoder)
    }
}
