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

    /// Access a query field for a given model key.
    public subscript(_ key: AnyKeyPath) -> QueryField? {
        let modelKey = ModelKey(
            path: key,
            type: Any.self,
            isOptional: false
        )
        return storage[modelKey]
    }
}

/// A model property containing the
/// Swift key path for accessing it.
public struct ModelKey: Hashable {
    /// See Hashable.hashValue
    public var hashValue: Int {
        return path.hashValue
    }

    /// See Equatable.==
    public static func ==(lhs: ModelKey, rhs: ModelKey) -> Bool {
        return lhs.path == rhs.path
    }

    /// The Swift keypath
    var path: AnyKeyPath

    /// The properties type.
    /// Storing this as any since we lost
    /// the type info converting to AnyKeyPAth
    var type: Any.Type

    /// True if the property on the model is optional.
    /// The `type` is the Wrapped type if this is true.
    var isOptional: Bool

    /// Create a new model key.
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
