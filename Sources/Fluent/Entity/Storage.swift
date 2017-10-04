import Foundation

public final class Storage: Codable {
    public init() {}

    // Entity
    fileprivate var exists: Bool = false

    // FIXME: should we still have id auto implemented here?
    fileprivate var id: Encodable? = nil

    // Timestampable

    // FIXME: should we auto implement this?
    internal var createdAt: Date? = nil
    internal var updatedAt: Date? = nil

    // SoftDeletable
    internal var deletedAt: Date? = nil
    internal var shouldForceDelete: Bool = false
    
    // Dirty key updates

    // FIXME: fetched row?
    // internal var fetchedRow: Row? = nil

    // Codable
    public func encode(to encoder: Encoder) throws {
        // nothing
    }

    public convenience init(from decoder: Decoder) throws {
        self.init()
    }
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
    public var id: Encodable? {
        get {
            return storage.id
        }
        nonmutating set {
            storage.id = newValue
        }
    }
}
