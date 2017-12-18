import Async
import JunkDrawer
import Service

/// Fluent database models. These types can be fetched
/// from a database connection using a query.
///
/// Types conforming to this protocol provide the basis
/// fetching and saving data to/from Fluent.
public protocol Model: AnyModel, ContainerFindable {
    /// The type of database this model can be queried on.
    associatedtype Database: Fluent.Database

    /// The associated Identifier type.
    /// Usually Int or UUID.
    associatedtype ID: Fluent.ID

    /// Key path to identifier
    typealias IDKey = ReferenceWritableKeyPath<Self, ID?>

    /// This model's id key.
    /// note: If this is not `id`, you
    /// will still need to implement `var id`
    /// on your model as a computed property.
    static var idKey: IDKey { get }

    /// Called before a model is created when saving.
    /// Throwing will cancel the save.
    func willCreate(on connection: Database.Connection)  throws -> Future<Void>
    /// Called after the model is created when saving.
    func didCreate(on connection: Database.Connection) throws -> Future<Void>

    /// Called before a model is updated when saving.
    /// Throwing will cancel the save.
    func willUpdate(on connection: Database.Connection) throws -> Future<Void>
    /// Called after the model is updated when saving.
    func didUpdate(on connection: Database.Connection) throws -> Future<Void>

    /// Called before a model is deleted.
    /// Throwing will cancel the deletion.
    func willDelete(on connection: Database.Connection) throws -> Future<Void>
    /// Called after the model is deleted.
    func didDelete(on connection: Database.Connection) throws -> Future<Void>
}

/// Type-erased model.
/// See Model
public protocol AnyModel: class, Codable {
    /// This model's unique name.
    static var name: String { get }

    /// This model's collection/table name
    static var entity: String { get }
}

extension Model {
    /// Creates a query for this model on the supplied connection.
    public func query(
        _ database: DatabaseIdentifier<Database>?,
        on conn: DatabaseConnectable
    ) -> QueryBuilder<Self> {
        let conn = Future<Database.Connection> {
            let dbid = try database ?? Self.requireDefaultDatabase()
            return conn.connect(to: dbid)
        }
        return .init(on: conn)
    }

    /// Creates a query for this model on the supplied connection.
    public static func query(
        _ database: DatabaseIdentifier<Database>?,
        on conn: DatabaseConnectable
    ) -> QueryBuilder<Self> {
        let conn = Future<Database.Connection> {
            let dbid = try database ?? Self.requireDefaultDatabase()
            return conn.connect(to: dbid)
        }
        return .init(on: conn)
    }
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
        var pluralName = name.replacingOccurrences(of: "([^aeiouy]|qu)y$", with: "$1ie", options: [.regularExpression])

        if pluralName.last != "s" {
            pluralName += "s"
        }

        return pluralName
    }

    /// Seee Model.willCreate()
    public func willCreate(on connection: Database.Connection) throws -> Future<Void> { return .done }
    /// See Model.didCreate()
    public func didCreate(on connection: Database.Connection) throws -> Future<Void> { return .done }

    /// See Model.willUpdate()
    public func willUpdate(on connection: Database.Connection) throws -> Future<Void> { return .done }
    /// See Model.didUpdate()
    public func didUpdate(on connection: Database.Connection) throws -> Future<Void> { return .done }

    /// See Model.willDelete()
    public func willDelete(on connection: Database.Connection) throws -> Future<Void> { return .done }
    /// See Model.didDelete()
    public func didDelete(on connection: Database.Connection) throws -> Future<Void> { return .done }
}

/// MARK: Convenience

extension Model {
    /// Returns the ID.
    /// Throws an error if the model doesn't have an ID.
    public func requireID() throws -> ID {
        guard let id = self.fluentID else {
            throw FluentError(identifier: "idRequired", reason: "\(Self.self) does not have an identifier.")
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
    public func save(
        to database: DatabaseIdentifier<Database>?,
        on conn: DatabaseConnectable
    ) -> Future<Void> {
        return query(database, on: conn).save(self)
    }

    /// Saves this model as a new item in the database.
    /// This method can auto-generate an ID depending on ID type.
    public func create(
        to database: DatabaseIdentifier<Database>?,
        on conn: DatabaseConnectable
    ) -> Future<Void> {
        return query(database, on: conn).create(self)
    }

    /// Updates the model. This requires that
    /// the model has its ID set.
    public func update(
        to database: DatabaseIdentifier<Database>?,
        on conn: DatabaseConnectable
    ) -> Future<Void> {
        return query(database, on: conn).update(self)
    }

    /// Saves this model to the supplied query executor.
    /// If `shouldCreate` is true, the model will be saved
    /// as a new item even if it already has an identifier.
    public func delete(
        to database: DatabaseIdentifier<Database>?,
        on conn: DatabaseConnectable
    ) -> Future<Void> {
        return query(database, on: conn).delete(self)
    }

    /// Attempts to find an instance of this model w/
    /// the supplied identifier.
    public static func find(
        _ id: Self.ID,
        from database: DatabaseIdentifier<Database>? = nil,
        on conn: DatabaseConnectable
    ) -> Future<Self?> {
        return Future {
            return try query(database, on: conn)
                .filter(idKey == id)
                .first()
        }
    }
}

// MARK: Default Database

/// Private static default database storage.
private var _defaultDatabases: [ObjectIdentifier: Any] = [:]

extension Model {
    /// This Model's default database. This will be used
    /// when no database id is passed (for example, on `Model.query(on:)`,
    /// or when it is not possible to pass a database (such as static lookup).
    public static var defaultDatabase: DatabaseIdentifier<Database>? {
        get { return _defaultDatabases[ObjectIdentifier(Self.self)] as? DatabaseIdentifier<Database> }
        set { _defaultDatabases[ObjectIdentifier(Self.self)] = newValue }
    }

    /// Returns the `.defaultDatabase` or throws an error.
    public static func requireDefaultDatabase() throws -> DatabaseIdentifier<Database> {
        guard let dbid = Self.defaultDatabase else {
            fatalError()
            throw FluentError(
                identifier: "noDefaultDatabase",
                reason: "A default database is required if no database ID is passed to `\(Self.self).query(_:on:)` or if `\(Self.self)` is being looked up statically. Set `\(Self.self).defaultDatabase` or to fix this error."
            )
        }
        return dbid
    }
}

// MARK: Container Findable

extension Model {
    /// See EphemeralWorkerFindable.find
    public static func find(identifier: String, using container: Container) throws -> Future<Self> {
        guard let idType = ID.self as? StringDecodable.Type else {
            throw FluentError(
                identifier: "invalidIDType",
                reason: "Could not convert string to ID. Conform `\(ID.self)` to `StringDecodable` to fix this error."
            )
        }

        guard let id = idType.decode(from: identifier) as? ID else {
            throw FluentError(
                identifier: "invalidID",
                reason: "Could not convert parameter \(identifier) to type `\(ID.self)`"
            )
        }

        let dbid = try Self.requireDefaultDatabase()
        if let ephemeral = container as? EphemeralContainer {
            return ephemeral.connect(to: dbid).flatMap(to: Self.self) { conn in
                return self.find(id, on: conn).map(to: Self.self) { model in
                    guard let model = model else {
                        throw FluentError(identifier: "entity-not-found", reason: "no model with ID \(id) was found")
                    }
                    return model
                }
            }
        } else {
            return container.withConnection(to: dbid) { conn in
                return self.find(id, on: conn).map(to: Self.self) { model in
                    guard let model = model else {
                        throw FluentError(identifier: "entity-not-found", reason: "no model with ID \(id) was found")
                    }
                    return model
                }
            }
        }
    }
}

