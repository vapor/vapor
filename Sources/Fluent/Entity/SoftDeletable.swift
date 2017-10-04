import Foundation

/// Conforming an entity to SoftDeletable
/// allows the entity to be temporarily deleted
/// with the possibility to restore.
public protocol SoftDeletable: Model {
    /// Table key to use for deleted at date
    static var deletedAtKey: String { get }

    /// Optional date the entity was deleted at.
    /// If `nil`, the entity has not been deleted
    var deletedAt: Date? { get set }

    // hooks
    func willSoftDelete() throws
    func didSoftDelete()
    func willForceDelete() throws
    func didForceDelete()
    func willRestore() throws
    func didRestore()
}

// MARK: Methods

extension SoftDeletable {
    /// Soft deletes the entity, setting
    /// its `deletedAt` date to now
    /// - note: internal since it is meant
    ///         to be called by `model.delete()`
    internal func softDelete() throws {
        try assertExists()
        try willSoftDelete()
        deletedAt = Date()
        try save()
        didSoftDelete()
    }

    /// Permanently deletes the model.
    public func forceDelete() throws {
        try assertExists()
        try willForceDelete()
        shouldForceDelete = true
        try delete()
        didForceDelete()
    }

    /// Restores a soft deleted entity, 
    /// setting its `deletedAt` date to nil
    public func restore() throws {
        try assertExists()
        try willRestore()
        deletedAt = nil
        try makeQuery().withSoftDeleted().save()
        didRestore()
    }
}

// MARK: Defaults

extension SoftDeletable {
    public static var deletedAtKey: String {
        switch keyNamingConvention {
        case .camelCase:
            return "deletedAt"
        case .snake_case:
            return "deleted_at"
        }
    }

    public var deletedAt: Date? {
        get { return storage.deletedAt }
        set { storage.deletedAt = newValue }
    }
}

// MARK: Optional

extension SoftDeletable {
    public func willSoftDelete() {}
    public func didSoftDelete() {}
    public func willForceDelete() {}
    public func didForceDelete() {}
    public func willRestore() {}
    public func didRestore() {}
}

// MARK: Query

extension QueryRepresentable where E: SoftDeletable, Self: ExecutorRepresentable {
    /// Include soft deleted entities in the query
    public func withSoftDeleted() throws -> Query<E> {
        let query = try makeQuery()
        query.includeSoftDeleted = true
        return query
    }

    public func forceDelete() throws {
        let query = try makeQuery().withSoftDeleted()
        query.action = .delete
        try query.raw()
    }
}

// MARK: Entity

extension Model where Self: SoftDeletable {
    /// Includes soft deleted entities in
    /// the results
    public static func withSoftDeleted() throws -> Query<Self> {
        return try makeQuery().withSoftDeleted()
    }

    /// If true, calls to `model.delete()`
    /// should permanently delete the model.
    internal var shouldForceDelete: Bool {
        get { return storage.shouldForceDelete }
        set { storage.shouldForceDelete = newValue }
    }
}
