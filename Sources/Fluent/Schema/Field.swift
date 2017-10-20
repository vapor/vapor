public struct Field {
    /// The name of this field.
    public var name: String

    /// The type of field.
    public var type: FieldType

    /// True if the field supports nil.
    public var isOptional: Bool

    /// Is the primary identifier field.
    public var isIdentifier: Bool
}

public enum FieldType {
    case string
    case int
    case double
    case data
    case custom(String)
}

// MARK: Fields

extension SchemaBuilder {
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

    /// Adds a string type field.
    public func int(_ name: String, isOptional: Bool = false, isIdentifier: Bool = false) {
        let field = Field(
            name: name,
            type: .int,
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
    }

    /// Adds a string type field.
    public func double(_ name: String, isOptional: Bool = false, isIdentifier: Bool = false) {
        let field = Field(
            name: name,
            type: .double,
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
    }

    /// Adds a string type field.
    public func data(_ name: String, length: Int, isOptional: Bool = false, isIdentifier: Bool = false) {
        let field = Field(
            name: name,
            type: .data,
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
    }
}
