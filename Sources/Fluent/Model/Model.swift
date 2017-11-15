import Async

/// Fluent database models. These types can be fetched
/// from a database connection using a query.
///
/// Types conforming to this protocol provide the basis
/// fetching and saving data to/from Fluent.
public protocol Model: class, Codable, KeyFieldMappable {
    /// The type of database this model can be queried on.
    associatedtype Database: Fluent.Database

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
    func willCreate()  throws -> Future<Void>
    /// Called after the model is created when saving.
    func didCreate() throws -> Future<Void>

    /// Called before a model is updated when saving.
    /// Throwing will cancel the save.
    func willUpdate() throws -> Future<Void>
    /// Called after the model is updated when saving.
    func didUpdate() throws -> Future<Void>

    /// Called before a model is deleted.
    /// Throwing will cancel the deletion.
    func willDelete() throws -> Future<Void>
    /// Called after the model is deleted.
    func didDelete() throws -> Future<Void>
}

extension Model {
    /// Access the fluent identifier
    internal var fluentID: ID? {
        get { return self[keyPath: Self.idKey] }
        set { self[keyPath: Self.idKey] = newValue }
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
    public func willCreate() throws -> Future<Void> { return .done }
    /// See Model.didCreate()
    public func didCreate() throws -> Future<Void> { return .done }

    /// See Model.willUpdate()
    public func willUpdate() throws -> Future<Void> { return .done }
    /// See Model.didUpdate()
    public func didUpdate() throws -> Future<Void> { return .done }

    /// See Model.willDelete()
    public func willDelete() throws -> Future<Void> { return .done }
    /// See Model.didDelete()
    public func didDelete() throws -> Future<Void> { return .done }
}

/// MARK: Convenience

extension Model {
    /// Returns the ID.
    /// Throws an error if the model doesn't have an ID.
    public func requireID() throws -> ID {
        guard let id = self.fluentID else {
            throw "no id"
        }

        return id
    }
}

/// MARK: CRUD

extension Model {
    /// Saves the supplied model.
    /// Calls `create` if the ID is `nil`, and `update` if it exists.
    /// If you need to create a model with a pre-existing ID,
    /// call `create` instead.
    public func save(on connection: Database.Connection) -> Future<Void> {
        return connection.query(Self.self).save(self)
    }

    /// Saves this model as a new item in the database.
    /// This method can auto-generate an ID depending on ID type.
    public func create(on connection: Database.Connection) -> Future<Void> {
        return connection.query(Self.self).create(self)
    }

    /// Updates the model. This requires that
    /// the model has its ID set.
    public func update(on connection: Database.Connection) -> Future<Void> {
        return connection.query(Self.self).update(self)
    }

    /// Saves this model to the supplied query executor.
    /// If `shouldCreate` is true, the model will be saved
    /// as a new item even if it already has an identifier.
    public func delete(on connection: Database.Connection) -> Future<Void> {
        return connection.query(Self.self).delete(self)
    }

    /// Attempts to find an instance of this model w/
    /// the supplied identifier.
    public static func find(_ id: Self.ID, on connection: Database.Connection) -> Future<Self?> {
        return then {
            return try connection.query(Self.self)
                .filter(idKey == id)
                .first()
        }
    }
}
