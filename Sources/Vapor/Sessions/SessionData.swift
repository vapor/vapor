/// Codable session data.
public struct SessionData: Codable {
    /// Session codable object storage.
    internal var storage: [String: String] {
        /// Unilaterally set update flag when a key/value is set
        didSet {
            self.update = true
        }
    }
    /// Flag for wheter session data has changed state (through initial creation or mutation)
    internal var update: Bool
    
    /// Create a new, empty session data
    public init(_ data: [String: String] = [:]) {
        self.storage = data
        self.update = false
    }

    public init(from decoder: Decoder) throws {
        self.storage = try .init(from: decoder)
        self.update = false
    }

    public func encode(to encoder: Encoder) throws {
        try self.storage.encode(to: encoder)
    }
    
    /// Convenience `[String: String]` accessor.
    public subscript(_ key: String) -> String? {
        get { return self.storage[key] }
        set { self.storage[key] = newValue }
    }
}
