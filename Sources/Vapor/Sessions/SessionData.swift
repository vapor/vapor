/// Codable session data.
///
/// Direct user interaction to `SessionData` is limited to subscripting accessors which read/store only
/// in `SessionData.storage`; any other fields are limited to internal access only
public struct SessionData: Codable {
    public typealias Data = [String: String]
    public typealias Expiration = Date
    
    /// Session codable object storage for user info
    public internal(set) var storage: Data {
        /// Unilaterally set update flag when a key/value is set
        didSet {
            self.userStorageChanged = true
        }
    }
    
    /// Session codable object storage for Vapor
    public internal(set) var appStorage: Data {
       /// Unilaterally set update flag when a key/value is set
       didSet {
           self.appStorageChanged = true
       }
    }
    
    /// Expiration time of the session
    public internal(set) var expiration: Expiration {
        didSet {
            self.expiryChanged = true
        }
    }

    /// Flags for whether session data has changed state (through initial creation or mutation)
    public internal(set) var userStorageChanged: Bool
    public internal(set) var appStorageChanged: Bool
    public internal(set) var expiryChanged: Bool
    
    
    /// Create a new, empty session data
    public init(_ data: [String: String] = [:]) {
        self.storage = data
        self.userStorageChanged = false
        self.appStorage = [:]
        self.appStorageChanged = false
        self.expiration = .distantFuture
        self.expiryChanged = false
    }
    
    internal init(user: [String: String] = [:], app: [String: String] = [:], expiration: Date) {
        self.storage = user
        self.appStorage = app
        self.expiration = expiration
        self.userStorageChanged = false
        self.appStorageChanged = false
        self.expiryChanged = false
    }

    public init(from decoder: Decoder) throws {
        self.storage = try .init(from: decoder)
        self.appStorage = try .init(from: decoder)
        self.expiration = try .init(from: decoder)
        self.userStorageChanged = false
        self.appStorageChanged = false
        self.expiryChanged = false
    }

    public func encode(to encoder: Encoder) throws {
        try self.storage.encode(to: encoder)
        try self.appStorage.encode(to: encoder)
        try self.expiration.encode(to: encoder)
    }
    
    /// Convenience `[String: String]` accessor.
    public subscript(_ key: String) -> String? {
        get { return self.storage[key] }
        set { self.storage[key] = newValue }
    }
    
    public mutating func resetFlags() {
        userStorageChanged = false
        appStorageChanged = false
        expiryChanged = false
    }
    
    public var anyUpdated: Bool {
        return userStorageChanged || appStorageChanged || expiryChanged
    }
}
