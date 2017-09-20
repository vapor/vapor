/// When added to an entity, timestamps
/// will automatically be created during
/// preparation and updated when the model saves.
public protocol Timestampable: Entity {
    static var updatedAtKey: String { get }
    static var createdAtKey: String { get }
    var createdAt: Date? { get set }
    var updatedAt: Date? { get set }
}

// MARK: Defaults

extension Timestampable {
    public static var updatedAtKey: String {
        switch keyNamingConvention {
        case .camelCase:
            return "updatedAt"
        case .snake_case:
            return "updated_at"
        }
    }

    public static var createdAtKey: String {
        switch keyNamingConvention {
        case .camelCase:
            return "createdAt"
        case .snake_case:
            return "created_at"
        }
    }

    public var createdAt: Date? {
        get { return storage.createdAt }
        set { storage.createdAt = newValue }
    }

    public var updatedAt: Date? {
        get { return storage.updatedAt }
        set { storage.updatedAt = newValue }
    }
}
