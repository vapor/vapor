/// A container for storing data associated with a given `SessionID`.
///
/// You can add data to an instance of `SessionData` by subscripting:
///
///     let data = SessionData()
///     data["login_date"] = "\(Date())"
///
/// If you need a snapshot of the data stored in the container, such as for custom serialization to storage drivers, you can get a copy with `.snapshot`.
///
///     let data: SessionData = ["name": "Vapor"]
///     // creates a copy of the data as of this point
///     let snapshot = data.snapshot
///     client.storeUsingDictionary(snapshot)
public struct SessionData: Sendable {
    /// A copy of the current data in the container.
    public var snapshot: [String: String] { self.storage }

    private var storage: [String: String]
    
    /// Creates a new empty session data container.
    public init() {
        self.storage = [:]
    }

    /// Creates a session data container for the given data.
    
    /// - Parameter data: The data to store in the container.
    public init(initialData data: [String: String]) {
        self.storage = data
    }

    /// Get and set values in the container by key.
    public subscript(_ key: String) -> String? {
        get { self.storage[key] }
        set { self.storage[key] = newValue }
    }
}

// MARK: Equatable

extension SessionData: Equatable {
    public static func == (lhs: SessionData, rhs: SessionData) -> Bool {
        lhs.storage == rhs.storage
    }
}

// MARK: Codable

extension SessionData: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.storage = try container.decode([String: String].self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.storage)
    }
}

// MARK: ExpressibleByDictionaryLiteral

extension SessionData: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, String)...) {
        self.init(initialData: .init(elements, uniquingKeysWith: { $1 }))
    }
}
