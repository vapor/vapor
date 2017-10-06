/// Fluent model storage.
public final class Storage: Codable {
    internal var exists: Bool

    /// Create a new Fluent model storage object.
    public init() {
        self.exists = false
    }

    /// See Decodable.init(from:)
    public convenience init(from decoder: Decoder) {
        self.init()
    }

    /// See Encodable.encode(to:)
    public func encode(to encoder: Encoder) {
        // nothing
    }
}

extension Model {
    /// Returns true if the model exists in the database.
    /// (Has been fetched from the database or saved to it).
    public var exists: Bool {
        get { return storage.exists }
        set { storage.exists = newValue }
    }
}
