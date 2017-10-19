/// A query that can be sent to a Fluent database.
public struct DatabaseSchema {
    /// The entity to query
    public let entity: String

    /// The action to perform on the database
    public var action: SchemaAction

    /// The fields to add to this schema
    public var addFields: [Field]

    /// The fields to be removed from this schema.
    public var removeFields: [String]

    /// Create a new database query.
    public init(entity: String) {
        self.entity = entity
        self.action = .create
        self.addFields = []
        self.removeFields = []
    }
}
