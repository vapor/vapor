import Foundation

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

/// Capable of being a schema field type.
public protocol SchemaFieldType {
    /// Convert to a string representation of
    /// the schema field type.
    func schemaFieldTypeString() -> String
}

// MARK: Fields

extension SchemaBuilder {
    /// Adds an ID field for this model to the schema.
    public func id() throws {
        try field(for: Model.idKey)
    }

    /// Adds a field to the schema.
    @discardableResult
    public func field<
        T: SchemaFieldTypeRepresentable
    >(for key: KeyPath<Model, Optional<T>>) throws -> SchemaField {
        return try field(T.makeSchemaFieldType(), key, isOptional: true, isIdentifier: key == Model.idKey)
    }

    /// Adds a field to the schema.
    @discardableResult
    public func field<
        T: SchemaFieldTypeRepresentable
    >(for key: KeyPath<Model, T>) throws -> SchemaField {
        return try field(T.makeSchemaFieldType(), key, isOptional: false, isIdentifier: false)
    }

    /// Adds a field to the schema.
    @discardableResult
    public func field<Field: QueryFieldRepresentable>(
        _ type: SchemaFieldType,
        _ field: Field,
        isOptional: Bool = false,
        isIdentifier: Bool = false
    ) throws -> SchemaField {
        let field = SchemaField(
            name: try field.makeQueryField().name,
            type: type,
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
        return field
    }
}

public protocol SchemaFieldTypeRepresentable {
    static func makeSchemaFieldType() -> SchemaFieldType
}

extension String: SchemaFieldTypeRepresentable {
    public static func makeSchemaFieldType() -> SchemaFieldType {
        return .string(nil)
    }
}

extension Int: SchemaFieldTypeRepresentable {
    public static func makeSchemaFieldType() -> SchemaFieldType {
        return .int
    }
}

extension Date: SchemaFieldTypeRepresentable {
    public static func makeSchemaFieldType() -> SchemaFieldType {
        return .date
    }
}

extension Double: SchemaFieldTypeRepresentable {
    public static func makeSchemaFieldType() -> SchemaFieldType {
        return .double
    }
}

extension UUID: SchemaFieldTypeRepresentable {
    public static func makeSchemaFieldType() -> SchemaFieldType {
        return .data(16)
    }
}
