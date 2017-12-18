/// The children relation is one side of a
/// one-to-many database relation.
///
/// The children relation will return all the
/// models that contain a reference to the parent's identifier.
///
/// The opposite side of this relation is called `Parent`.
public struct Children<Parent: Model, Child: Model>
    where Parent.Database == Child.Database
{
    /// Reference to the parent's ID
    public var parent: Parent

    /// Key referencing property storing parent's ID
    public typealias ParentForeignIDKey = KeyPath<Child, Parent.ID>

    /// Reference to the foreign key on the child.
    public var parentForeignIDKey: ParentForeignIDKey

    /// Creates a new children relationship.
    public init(parent: Parent, parentForeignIDKey: ParentForeignIDKey) {
        self.parent = parent
        self.parentForeignIDKey = parentForeignIDKey
    }

    /// Create a query for all children.
    public func query(on conn: DatabaseConnectable) throws -> QueryBuilder<Child> {
        return try Child.query(on: conn)
            .filter(parentForeignIDKey.makeQueryField() == parent.requireID())
    }
}

// MARK: Model

extension Model {
    /// Create a children relation for this model.
    ///
    /// The `foreignField` should refer to the field
    /// on the child entity that contains the parent's ID.
    public func children<Child: Model>(
        _ parentForeignIDKey: Children<Self, Child>.ParentForeignIDKey
    ) -> Children<Self, Child> {
        return Children(
            parent: self,
            parentForeignIDKey: parentForeignIDKey
        )
    }
}
