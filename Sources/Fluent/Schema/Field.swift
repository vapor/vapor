public struct Field {
    /// The name of this field.
    public var name: String

    /// The type of field.
    public var type: FieldType

    /// True if the field supports nil.
    public var isOptional: Bool

    /// Is the primary identifier field.
    public var isIdentifier: Bool

    /// Create a new field.
    public init(name: String, type: FieldType, isOptional: Bool = false, isIdentifier: Bool = false) {
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.isIdentifier = isIdentifier
    }
}

/// Supported database field types.
public enum FieldType {
    case string
    case int
    case double
    case data
    case date
    case custom(String)
}

// MARK: Fields

extension SchemaBuilder {
    public func id() {
        let field = Field(
            name: "id",
            type: ModelType.Identifier.fieldType,
            isOptional: false,
            isIdentifier: true
        )
        schema.addFields.append(field)
    }

    /// Adds a string type field.
    public func string(_ name: String, isOptional: Bool = false, isIdentifier: Bool = false) {
        let field = Field(
            name: name,
            type: .string,
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
    }

    /// Adds a int type field.
    public func int(_ name: String, isOptional: Bool = false, isIdentifier: Bool = false) {
        let field = Field(
            name: name,
            type: .int,
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
    }

    /// Adds a double type field.
    public func double(_ name: String, isOptional: Bool = false, isIdentifier: Bool = false) {
        let field = Field(
            name: name,
            type: .double,
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
    }

    /// Adds a data type field.
    public func data(_ name: String, length: Int, isOptional: Bool = false, isIdentifier: Bool = false) {
        let field = Field(
            name: name,
            type: .data,
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
    }

    /// Adds a date type field.
    public func date(_ name: String, isOptional: Bool = false, isIdentifier: Bool = false) {
        let field = Field(
            name: name,
            type: .date,
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
    }
}
