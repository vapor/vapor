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
    public var foreignKey: String

    /// Creates a new children relationship.
    public init(parent: Parent, foreignKey: String) {
        self.parent = parent
        self.foreignKey = foreignKey
    }

    /// Create a query for all children.
    public func query(on executor: QueryExecutor) -> QueryBuilder<Child> {
        let builder = executor.query(Child.self)
        return builder.filter(foreignKey == parent.id)
    }
}

// MARK: Model

extension Model {
    /// Create a children relation for this model.
    public func children<Child: Model>(
        foreignKey: String = "\(Self.name)ID"
    ) -> Children<Self, Child> {
        return Children(
            parent: self,
            foreignKey: foreignKey
        )
    }
}
