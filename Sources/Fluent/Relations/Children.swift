/// The children relation is one side of a
/// one-to-many database relation.
///
/// The children relation will return all the
/// models that contain a reference to the parent's identifier.
///
/// The opposite side of this relation is called `Parent`.
public struct Children<Parent: Model, Child: Model> {
    /// Reference to the parent's ID
    public var parent: Parent

    /// Reference to the foreign key on the child.
    public var foreignField: QueryField

    /// Creates a new children relationship.
    public init(parent: Parent, foreignField: QueryField) {
        self.parent = parent
        self.foreignField = foreignField
    }

    /// Create a query for all children.
    public func query(on executor: QueryExecutor) throws -> QueryBuilder<Child> {
        let builder = executor.query(Child.self)
        return try builder.filter(foreignField == parent.requireID())
    }
}

// MARK: Model

extension Model {
    /// Create a children relation for this model.
    ///
    /// The `foreignField` should refer to the field
    /// on the child entity that contains the parent's ID.
    public func children<Child: Model>(
        foreignField: QueryField = Child.field(Self.foreignIDKey)
    ) -> Children<Self, Child> {
        return Children(
            parent: self,
            foreignField: foreignField
        )
    }
}
