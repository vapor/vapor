/// A foreign key is a field (or collection of fields) in one table
/// that uniquely identifies a row of another table or the same table.
public struct ForeignKey {
    /// The entity type of the local field
    public let entity: Model.Type
    /// The name of the field to hold the reference
    public let field: String
    /// The name of the field being referenced
    public let foreignField: String
    /// The entity type of the foreign field being referenced
    public let foreignEntity: Model.Type
    /// The unique identifying name of this foreign key
    public var name: String
    
    /// Creates a new ForeignKey
    public init(
        entity: Model.Type,
        field: String,
        foreignField: String,
        foreignEntity: Model.Type,
        name: String? = nil
    ) {
        self.entity = entity
        self.field = field
        self.foreignField = foreignField
        self.foreignEntity = foreignEntity
        self.name = name ?? "_fluent_fk_\(entity.entity).\(field)-\(foreignEntity.entity).\(foreignField)"
    }
}
