import Async

/// Defines database types that support references
public protocol ReferenceSupporting: SchemaSupporting {
    /// Enables references errors.
    func enableReferences() -> Future<Void>

    /// Disables reference errors.
    func disableReferences() -> Future<Void>
}

/// A reference / foreign key is a field (or collection of fields) in one table
/// that uniquely identifies a row of another table or the same table.
public struct SchemaReference {
    /// The base field.
    public let base: SchemaField

    /// The field this base field references.
    /// Note: this is a `QueryField` because we have limited info.
    /// we assume it is the same type as the base field.
    public let referenced: QueryField

    /// Creates a new SchemaReference
    public init(
        base: SchemaField,
        referenced: QueryField
    ) {
        self.base = base
        self.referenced = referenced
    }
}

extension DatabaseSchema {
    /// Field to field references for this database schema.
    public var references: [SchemaReference] {
        get { return extend["references"] as? [SchemaReference] ?? [] }
        set { extend["references"] = newValue }
    }
}

extension SchemaBuilder where Model.Database.Connection: ReferenceSupporting {
    /// Adds a field to the schema and creates a reference.
    /// T : T
    public func field<
        T: SchemaFieldTypeRepresentable,
        Other: Fluent.Model
    >(for key: KeyPath<Model, T>, referencing: KeyPath<Other, T>) throws {
        let base = try field(for: key)
        let reference = try SchemaReference(base: base, referenced: referencing.makeQueryField())
        schema.references.append(reference)
    }

    /// Adds a field to the schema and creates a reference.
    /// T : Optional<T>
    public func field<
        T: SchemaFieldTypeRepresentable,
        Other: Fluent.Model
    >(for key: KeyPath<Model, T>, referencing: KeyPath<Other, Optional<T>>) throws {
        let base = try field(for: key)
        let reference = try SchemaReference(base: base, referenced: referencing.makeQueryField())
        schema.references.append(reference)
    }

    /// Adds a field to the schema and creates a reference.
    /// Optional<T> : T
    public func field<
        T: SchemaFieldTypeRepresentable,
        Other: Fluent.Model
    >(for key: KeyPath<Model, Optional<T>>, referencing: KeyPath<Other, T>) throws {
        let base = try field(for: key)
        let reference = try SchemaReference(base: base, referenced: referencing.makeQueryField())
        schema.references.append(reference)
    }

    /// Adds a field to the schema and creates a reference.
    /// Optional<T> : Optional<T>
    public func field<
        T: SchemaFieldTypeRepresentable,
        Other: Fluent.Model
    >(for key: KeyPath<Model, Optional<T>>, referencing: KeyPath<Other, Optional<T>>) throws {
        let base = try field(for: key)
        let reference = try SchemaReference(base: base, referenced: referencing.makeQueryField())
        schema.references.append(reference)
    }
}
