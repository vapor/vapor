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
        guard let model = Root.self as? AnyModel.Type else {
            throw FluentError(identifier: "invalid-root-type", reason: "`Can't create query field. \(Root.self)` does not conform to `AnyModel`.")
        }

        let key = model.unsafeCodingPath(forKey: self)
        return QueryField(entity: model.entity, name: key[0].stringValue)
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

extension Model {
    /// Creates a query field decoding container for this model.
    public static func decodingContainer(for decoder: Decoder) throws -> QueryFieldDecodingContainer<Self> {
        let container = try decoder.container(keyedBy: QueryField.self)
        return QueryFieldDecodingContainer(container: container)
    }

    /// Creates a query field encoding container for this model.
    public func encodingContainer(for encoder: Encoder) -> QueryFieldEncodingContainer<Self> {
        let container = encoder.container(keyedBy: QueryField.self)
        return QueryFieldEncodingContainer(container: container, model: self)
    }
}

/// A container for decoding model key paths.
public struct QueryFieldDecodingContainer<Model: Fluent.Model> {
    /// The underlying container.
    public var container: KeyedDecodingContainer<QueryField>
    
    /// Decodes a model key path to a type.
    public func decode<T: Decodable>(key: KeyPath<Model, T>) throws -> T {
        let field = try key.makeQueryField()
        return try container.decode(T.self, forKey: field)
    }
}

/// A container for encoding model key paths.
public struct QueryFieldEncodingContainer<Model: Fluent.Model> {
    /// The underlying container.
    public var container: KeyedEncodingContainer<QueryField>

    /// The model being encoded.
    public var model: Model

    /// Encodes a model key path to the encoder.
    public mutating func encode<T: Encodable>(key: KeyPath<Model, T>) throws {
        let field = try key.makeQueryField()
        let value: T = model[keyPath: key]
        try container.encode(value, forKey: field)
    }
}
