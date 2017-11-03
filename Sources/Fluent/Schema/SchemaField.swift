public struct SchemaField {
    /// The name of this field.
    public var name: String

    /// The type of field.
    public var type: SchemaFieldType

    /// True if the field supports nil.
    public var isOptional: Bool

    /// Is the primary identifier field.
    public var isIdentifier: Bool

    /// Create a new field.
    public init(name: String, type: SchemaFieldType, isOptional: Bool = false, isIdentifier: Bool = false) {
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.isIdentifier = isIdentifier
    }
}

/// Supported database field types.
public enum SchemaFieldType {
    case string(length: Int?)
    case int
    case double
    case data(length: Int)
    case date
    case custom(type: String)
}

// MARK: Fields

extension SchemaBuilder {
    public func id() {
        let field = SchemaField(
            name: Model.idKey.makeQueryField().name,
            type: Model.ID.fieldType,
            isOptional: false,
            isIdentifier: true
        )
        schema.addFields.append(field)
    }

    public func id<Other: Fluent.Model>(for model: Other.Type, key: KeyPath<Model, Other.ID>) {
        let field = SchemaField(
            name: key.makeQueryField().name,
            type: Other.ID.fieldType,
            isOptional: false,
            isIdentifier: false
        )
        schema.addFields.append(field)
    }

    /// Adds a string type field.
    public func string(_ name: String, length: Int? = nil, isOptional: Bool = false, isIdentifier: Bool = false) {
        let field = SchemaField(
            name: name,
            type: .string(length: length),
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
    }

    /// Adds a int type field.
    public func int(_ name: String, isOptional: Bool = false, isIdentifier: Bool = false) {
        let field = SchemaField(
            name: name,
            type: .int,
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
    }

    /// Adds a double type field.
    public func double(_ name: String, isOptional: Bool = false, isIdentifier: Bool = false) {
        let field = SchemaField(
            name: name,
            type: .double,
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
    }

    /// Adds a data type field.
    public func data(_ name: String, length: Int, isOptional: Bool = false, isIdentifier: Bool = false) {
        let field = SchemaField(
            name: name,
            type: .data(length: length),
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
    }

    /// Adds a date type field.
    public func date(_ name: String, isOptional: Bool = false, isIdentifier: Bool = false) {
        let field = SchemaField(
            name: name,
            type: .date,
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
    }
}
