/// Represents a one-to-many relationship
/// from a parent entity to many children entities.
/// ex: child entities have a "parent_id"
public final class Children<
    Parent: Model, Child: Model
> {
    /// The parent entity id. This
    /// will be used to filter the children
    /// entities.
    public let parent: Parent
    
    /// The parent entity's foreign id key.
    /// Usually Parent.foreignIdKey.
    public let foreignIdKey: String

    /// Create a new Children relation.
    public init(
        from parent: Parent,
        to childType: Child.Type = Child.self,
        foreignIdKey: String = Parent.foreignIdKey
    ) {
        self.parent = parent
        self.foreignIdKey = foreignIdKey
    }
}

extension Children: QueryRepresentable {
    public func makeQuery(_ executor: Executor) throws -> Query<Child> {
        guard let parentId = parent.id else {
            throw RelationError.idRequired(parent)
        }

        return try Child.makeQuery(executor).filter(foreignIdKey == parentId)
    }
}

extension Children: ExecutorRepresentable {
    public func makeExecutor() throws -> Executor {
        return try Child.makeExecutor()
    }
}

extension Model {
    public func children<Child: Model>(
        type childType: Child.Type = Child.self,
        foreignIdKey: String = Self.foreignIdKey
    ) -> Children<Self, Child> {
        return Children(from: self, foreignIdKey: foreignIdKey)
    }
}
