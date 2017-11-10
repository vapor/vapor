import Async

/// The parent relation is one side of a
/// one-to-many database relation.
///
/// The parent relation will return the parent
/// model that the supplied child references.
///
/// The opposite side of this relation is called `Children`.
public struct Parent<Child: Model, Parent: Model>
    where Child.Database == Parent.Database
{
    /// The child object with reference to parent
    public var child: Child

    /// Key referencing property storing parent's ID
    public typealias ParentForeignIDKey = KeyPath<Child, Parent.ID>

    /// Reference to the parent's ID
    public var parentForeignIDKey: ParentForeignIDKey

    /// Creates a new children relationship.
    public init(child: Child, parentForeignIDKey: ParentForeignIDKey) {
        self.child = child
        self.parentForeignIDKey = parentForeignIDKey
    }

    /// Create a query for the parent.
    public func query(
        on connection: Child.Database.Connection
    ) throws -> QueryBuilder<Parent> {
        let builder = connection.query(Parent.self)
        return try builder.filter(Parent.idKey == child[keyPath: parentForeignIDKey])
    }

    /// Convenience for getting the parent.
    public func get(
        on connection: Child.Database.Connection
    ) -> Future<Parent> {
        return then {
            try self.query(on: connection).first().map { first in
                guard let parent = first else {
                    throw "Parent not found"
                }
                return parent
            }
        }
    }
}

// MARK: Model

extension Model {
    /// Create a children relation for this model.
    public func parent<P: Model>(
        _ parentForeignIDKey: Parent<Self, P>.ParentForeignIDKey
    ) -> Parent<Self, P> {
        return Parent(
            child: self,
            parentForeignIDKey: parentForeignIDKey
        )
    }
}

