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

/// Capable of mapping Swift key path's to Fluent query fields.
public protocol KeyFieldMappable {
    /// Maps key paths to their codable key.
    static var keyFieldMap: KeyFieldMap { get }
}

public struct KeyFieldMap: ExpressibleByDictionaryLiteral {
    /// See ExpressibleByDictionaryLiteral.Key
    public typealias Key = ModelKey

    /// See ExpressibleByDictionaryLiteral.Value
    public typealias Value = QueryField

    /// Store the key and query field.
    internal var storage: [ModelKey: QueryField]

    /// See ExpressibleByDictionaryLiteral
    public init(dictionaryLiteral elements: (ModelKey, QueryField)...) {
        self.storage = [:]
        for (key, field) in elements {
            storage[key] = field
        }
    }

    /// Access a query field for a given model key.
    public subscript(_ key: ModelKey) -> QueryField? {
        return storage[key]
    }
}

extension Model {
    /// Access the fluent identifier
    internal var fluentID: ID? {
        get { return self[keyPath: Self.idKey] }
        set { self[keyPath: Self.idKey] = newValue }
    }
}

public struct ModelKey: Hashable {
    public var hashValue: Int {
        return path.hashValue
    }

    public static func ==(lhs: ModelKey, rhs: ModelKey) -> Bool {
        return lhs.path == rhs.path
    }

    var path: AnyKeyPath
    var type: Any.Type
    var isOptional: Bool

    init<T>(path: AnyKeyPath, type: T.Type, isOptional: Bool) {
        self.path = path
        self.type = type
        self.isOptional = isOptional
    }
}

extension Model {
    /// Maps a model's key path to AnyKeyPath.
    public static func key<T, K: KeyPath<Self, T>>(_ path: K) -> ModelKey {
        return ModelKey(path: path, type: T.self, isOptional: false)
    }

    /// Maps a model's key path to AnyKeyPath.
    public static func key<T, K: KeyPath<Self, Optional<T>>>(_ path: K) -> ModelKey {
        return ModelKey(path: path, type: T.self, isOptional: true)
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
