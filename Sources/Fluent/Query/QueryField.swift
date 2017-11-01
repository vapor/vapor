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
    func makeQueryField() -> QueryField
}

/// Strings should be usable as query fields in builder.filter(...) calls.
extension String: QueryFieldRepresentable {
    /// See QueryFieldRepresentable.makeQueryField
    public func makeQueryField() -> QueryField {
        return QueryField(name: self)
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


