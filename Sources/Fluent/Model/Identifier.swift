import Foundation

/// Types conforming to this protocol may be used
/// as identifiers for Fluent models.
public protocol Identifier: Codable, Equatable {
    /// The specific type of fluent identifier.
    /// This dictates how the identifier will behave when saved.
    static var identifierType: IdentifierType<Self> { get }

    /// The field type used to store this identifier.
    static var fieldType: SchemaFieldType { get }
}

/// MARK: Default supported types.

extension Int: Identifier {
    /// See Identifier.identifierType
    public static var identifierType: IdentifierType<Int> {
        return .autoincrementing
    }

    /// See Identifier.fieldType
    public static var fieldType: SchemaFieldType {
        return .int
    }
}

extension UUID: Identifier {
    /// See Identifier.identifierType
    public static var identifierType: IdentifierType<UUID> {
        return .generated { UUID() }
    }

    /// See Identifier.fieldType
    public static var fieldType: SchemaFieldType {
        return .data(length: 16)
    }
}

extension String: Identifier {
    /// See Identifier.identifierType
    public static var identifierType: IdentifierType<String> {
        return .supplied
    }

    /// See Identifier.fieldType
    public static var fieldType: SchemaFieldType {
        return .string(length: nil)
    }
}

