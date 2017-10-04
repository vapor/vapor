/// Modifies a schema. A subclass of Creator.
/// Can modify or delete fields.
public final class Modifier: Builder {
    /// The entity being modified
    public var entity: Model.Type
    
    /// The fields to be created
    public var fields: [RawOr<Field>]
    
    /// The foreign keys to be created
    public var foreignKeys: [RawOr<ForeignKey>]
    
    /// The fields to be deleted
    public var deleteFields: [RawOr<Field>]
    
    /// The foreign keys to be deleted
    public var deleteForeignKeys: [RawOr<ForeignKey>]
    
    /// Creators a new modifier
    public init(_ e: Model.Type) {
        entity = e
        fields = []
        foreignKeys = []
        deleteFields = []
        deleteForeignKeys = []
    }
    
    /// Delete a field with the given name
    public func delete(_ field: String) {
        let field = Field(
            name: field,
            type: .custom(type: "delete")
        )
        deleteFields.append(.some(field))
    }
    
    /// Delete a foreign key
    public func deleteForeignKey<E: Model>(_ field: String, referencing: String, on: E.Type) {
        let fk = ForeignKey(
            entity: entity,
            field: field,
            foreignField: referencing,
            foreignEntity: on
        )
        deleteForeignKeys.append(.some(fk))
    }
    
    
    /// Delete a field with the given name
    public func delete(raw: String) {
        deleteFields.append(.raw(raw, []))
    }
}
