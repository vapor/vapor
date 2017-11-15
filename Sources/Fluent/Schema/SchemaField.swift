import Foundation

public struct SchemaField {
    /// The name of this field.
    public var name: String

    /// The type of field.
    public var type: String

    /// True if the field supports nil.
    public var isOptional: Bool

    /// Is the primary identifier field.
    public var isIdentifier: Bool

    /// Create a new field.
    public init(name: String, type: String, isOptional: Bool = false, isIdentifier: Bool = false) {
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.isIdentifier = isIdentifier
    }
}

// MARK: Fields

extension SchemaBuilder {
    /// Adds a field to the schema.
    @discardableResult
    public func field<T>(for key: KeyPath<Model, Optional<T>>) throws -> SchemaField
        where T: SchemaFieldTypeRepresentable, T.FieldType == Connection.FieldType
    {
        return try field(
            type: T.makeSchemaFieldType(),
            for: key,
            isOptional: true,
            isIdentifier: key == Model.idKey
        )
    }

    /// Adds a field to the schema.
    @discardableResult
    public func field<T>(for key: KeyPath<Model, T>) throws -> SchemaField
        where T: SchemaFieldTypeRepresentable, T.FieldType == Connection.FieldType
    {
        return try field(
            type: T.makeSchemaFieldType(),
            for: key,
            isOptional: false,
            isIdentifier: false
        )
    }

    /// Adds a field to the schema.
    @discardableResult
    public func field<T>(
        type: Connection.FieldType,
        for field: KeyPath<Model, T>,
        isOptional: Bool = false,
        isIdentifier: Bool = false
    ) throws -> SchemaField {
        let field = SchemaField(
            name: try field.makeQueryField().name,
            type: type.makeSchemaFieldTypeString(),
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
        return field
    }

    /// Adds a field to the schema.
    @discardableResult
    public func addField(
        type: Connection.FieldType,
        name: String,
        isOptional: Bool = false,
        isIdentifier: Bool = false
    ) -> SchemaField {
        let field = SchemaField(
            name: name,
            type: type.makeSchemaFieldTypeString(),
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
        return field
    }

    /// Adds a field to the schema.
    public func removeField<Field>(
        for field: Field
    ) throws
        where Field: QueryFieldRepresentable
    {
        let name = try field.makeQueryField().name
        schema.removeFields.append(name)
    }
}
