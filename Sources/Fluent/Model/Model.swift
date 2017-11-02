import Async

/// Fluent database models. These types can be fetched
/// from a database connection using a query.
///
/// Types conforming to this protocol provide the basis
/// fetching and saving data to/from Fluent.
public protocol Model: class, Codable {
    /// The associated Identifier type.
    /// Usually Int or UUID.
    associatedtype ID: Fluent.ID

    /// This model's unique name.
    static var name: String { get }

    /// This model's collection/table name
    static var entity: String { get }

    /// Key path to identifier
    typealias IDKey = ReferenceWritableKeyPath<Self, ID?>

    /// This model's id key.
    /// note: If this is not `id`, you
    /// will still need to implement `var id`
    /// on your model as a computed property.
    static var idKey: IDKey { get }

    /// Called before a model is created when saving.
    /// Throwing will cancel the save.
    func willCreate() throws
    /// Called after the model is created when saving.
    func didCreate()

    /// Called before a model is updated when saving.
    /// Throwing will cancel the save.
    func willUpdate() throws
    /// Called after the model is updated when saving.
    func didUpdate()

    /// Called before a model is deleted.
    /// Throwing will cancel the deletion.
    func willDelete() throws
    /// Called after the model is deleted.
    func didDelete()

    // MARK: Key paths

    /// Maps key paths to their codable key.
    static var keyFieldMap: [AnyKeyPath: QueryField] { get }
}

extension Model {
    /// Access the fluent identifier
    internal var fluentID: ID? {
        get { return self[keyPath: Self.idKey] }
        set { self[keyPath: Self.idKey] = newValue }
    }
}

extension Model {
    /// Maps a model's key path to AnyKeyPath.
    public static func key<T, K: KeyPath<Self, T>>(_ path: K) -> AnyKeyPath {
        return path
    }
}

/// Free implementations.
extension Model {
    /// See Model.name
    public static var name: String {
        return "\(Self.self)".lowercased()
    }

    /// See Model.entity
    public static var entity: String {
        return name + "s"
    }

    /// Seee Model.willCreate()
    public func willCreate() throws {}
    /// See Model.didCreate()
    public func didCreate() {}

    /// See Model.willUpdate()
    public func willUpdate() throws  {}
    /// See Model.didUpdate()
    public func didUpdate() {}

    /// See Model.willDelete()
    public func willDelete() throws {}
    /// See Model.didDelete()
    public func didDelete() {}
}

/// MARK: Convenience

extension Model {
    public func requireID() throws -> ID {
        guard let id = self.fluentID else {
            throw "no id"
        }

        return id
    }
}

/// MARK: CRUD

extension Model {
    /// Saves this model to the supplied query executor.
    /// If `shouldCreate` is true, the model will be saved
    /// as a new item even if it already has an identifier.
    public func save(
        on executor: QueryExecutor,
        shouldCreate: Bool = false
    ) -> Future<Void> {
        return executor.query(Self.self).save(self, shouldCreate: shouldCreate)
    }

    /// Saves this model to the supplied query executor.
    /// If `shouldCreate` is true, the model will be saved
    /// as a new item even if it already has an identifier.
    public func delete(
        on executor: QueryExecutor
    ) -> Future<Void> {
        return executor.query(Self.self).delete(self)
    }

    /// Attempts to find an instance of this model w/
    /// the supplied identifier.
    public static func find(_ id: Self.ID, on executor: QueryExecutor) -> Future<Self?> {
        let query = executor.query(Self.self)
        query.filter("id" == id)
        return query.first()
    }
}
