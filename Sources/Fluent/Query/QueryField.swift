/// Represents a field and its optional entity in a query.
/// This is used mostly for query filters.
public struct QueryField {
    /// The entity for this field.
    /// If the entity is nil, the query's default entity will be used.
    public var entity: String?

    /// The name of the field.
    public var name: String

    /// Create a new query field.
    public init(entity: String? = nil, name: String) {
        self.entity = entity
        self.name = name
    }
}

/// Representable as a Query Field
public protocol QueryFieldRepresentable {
    func makeQueryField() throws -> QueryField
}

/// Conform key path's where the root is a model.
/// FIXME: conditional conformance
extension KeyPath: QueryFieldRepresentable {
    /// See QueryFieldRepresentable.makeQueryField()
    public func makeQueryField() throws -> QueryField {
        guard let model = Root.self as? KeyFieldMappable.Type else {
            throw "`Can't create query field. \(Root.self)` does not conform to `Model`."
        }

        guard let queryField = model.keyFieldMap[self] else {
            throw "No query field on model `\(Root.self)` for key path `\(self)`"
        }

        return queryField
    }
}

/// Query fields obviously should get free conformance.
extension QueryField: QueryFieldRepresentable {
    public func makeQueryField() -> QueryField {
        return self
    }
}

/// Allow models to easily generate query fields statically.
extension Model {
    /// Generates a query field with the supplied name for this model.
    ///
    /// You can use this method to create static variables on your model
    /// for easier access without having to repeat strings.
    ///
    ///     extension User: Model {
    ///         static let nameField = User.field("name")
    ///     }
    ///
    public static func field(_ name: String) -> QueryField {
        return QueryField(entity: Self.entity, name: name)
    }
}

// MARK: Coding key

/// Allow query fields to be used as coding keys.
extension QueryField: CodingKey {
    /// See CodingKey.stringValue
    public var stringValue: String {
        return name
    }

    /// See CodingKey.intValue
    public var intValue: Int? {
        return nil
    }

    /// See CodingKey.init(stringValue:)
    public init?(stringValue: String) {
        self.init(name: stringValue)
    }

    /// See CodingKey.init(intValue:)
    public init?(intValue: Int) {
        return nil
    }
}

extension KeyedDecodingContainer where K == QueryField {
    /// Decodes a value from a key path.
    public func decode<T: Decodable, M: Model>(_ type: T.Type = T.self, forKey key: KeyPath<M, T>) throws -> T {
        let field = try key.makeQueryField()
        return try decode(T.self, forKey: field)
    }
}

extension KeyedEncodingContainer where K == QueryField {
    /// Encodes a value to a key path.
    public mutating func encode<T: Encodable, M: Model>(_ value: T, forKey key: KeyPath<M, T>) throws {
        let field = try key.makeQueryField()
        try self.encode(value, forKey: field)
    }
}

