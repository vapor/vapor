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

/// Supported database field types.
public enum SchemaFieldType {
    case string(Int?)
    case int
    case double
    case data(Int)
    case date
    case custom(type: String)
}

// MARK: Fields

extension SchemaBuilder {
    public func id() throws {
        try field(for: Model.idKey)
    }

    public func field<
        T: SchemaFieldTypeRepresentable
    >(for key: KeyPath<Model, Optional<T>>) throws {
        try field(T.makeSchemaFieldType(), key, isOptional: true, isIdentifier: key == Model.idKey)
    }

    /// Adds a field to the schema.
    public func field<
        T: SchemaFieldTypeRepresentable
    >(for key: KeyPath<Model, T>) throws {
        try field(T.makeSchemaFieldType(), key, isOptional: false, isIdentifier: false)
    }

    /// Adds a field to the schema.
    public func field<Field: QueryFieldRepresentable>(
        _ type: SchemaFieldType,
        _ field: Field,
        isOptional: Bool = false,
        isIdentifier: Bool = false
    ) throws {
        let field = SchemaField(
            name: try field.makeQueryField().name,
            type: type,
            isOptional: isOptional,
            isIdentifier: isIdentifier
        )
        schema.addFields.append(field)
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
