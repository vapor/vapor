public final class Storage {
    public init() {}

    // Entity
    fileprivate var exists: Bool = false
    fileprivate var id: Identifier? = nil

    // Timestampable
    internal var createdAt: Date? = nil
    internal var updatedAt: Date? = nil

    // SoftDeletable
    internal var deletedAt: Date? = nil
    internal var shouldForceDelete: Bool = false
    
    // Dirty key updates
    internal var fetchedRow: Row? = nil
}

public protocol Storable {
    /// General implementation should just be `let storage = Storage()`
    var storage: Storage { get }
}

extension Storable {
    /// Whether or not entity was retrieved from database.
    ///
    /// This value shouldn't be interacted w/ external users
    /// w/o explicit knowledge.
    ///
    public var exists: Bool {
        get {
            return storage.exists
        }
        nonmutating set {
            storage.exists = newValue
        }
    }

    /// The entity's primary identifier
    /// used for updating, filtering, deleting, etc.
    public var id: Identifier? {
        get {
            return storage.id
        }
        nonmutating set {
            storage.id = newValue
        }
    }
}
