/// Represents a one-to-many relationship
/// from a child entity to its parent.
/// ex: child entities have a "parent_id"
public final class Parent<
    Child: Model, Parent: Model
> {
    /// The parent entity id. This
    /// will be used to find the parent.
    public let parentId: Encodable

    /// The child requesting its parent
    public let child: Child
    /// Returns the parent.
    public func get() throws -> Parent? {
        return try first()
    }

    /// Creates a new Parent relation.
    public init(
        from child: Child,
        to parentType: Parent.Type = Parent.self,
        withId parentId: Encodable
    ) {
        self.child = child
        self.parentId = parentId
    }
}

extension Parent: QueryRepresentable {
    public func makeQuery(_ executor: Executor) throws -> Query<Parent> {
        let query = try Parent.makeQuery(executor)
        return try query.filter(Parent.idKey, parentId)
    }
}

extension Parent: ExecutorRepresentable {
    public func makeExecutor() throws -> Executor {
        return try Parent.makeExecutor()
    }
}

extension Model {
    public func parent<P: Model>(
        id parentId: Encodable?,
        type parentType: P.Type = P.self
    ) -> Parent<Self, P> {
        let id = parentId ?? Identifier(.null)
        return Parent(from: self, withId: id)
    }
}
