import Async

/// The parent relation is one side of a
/// one-to-many database relation.
///
/// The parent relation will return the parent
/// model that the supplied child references.
///
/// The opposite side of this relation is called `Children`.
public struct Parent<Child: Model, Parent: Model> {
    /// The child object with reference to parent
    public var child: Child

    /// Key referencing property storing parent's ID
    public typealias ParentIDKey = ReferenceWritableKeyPath<Child, Parent.Identifier>

    /// Reference to the parent's ID
    public var parentIDKey: ParentIDKey

    /// Creates a new children relationship.
    public init(child: Child, idKey: ParentIDKey) {
        self.child = child
        self.parentIDKey = idKey
    }

    /// Create a query for the parent.
    public func query(on executor: QueryExecutor) -> QueryBuilder<Parent> {
        let builder = executor.query(Parent.self)
        return builder.filter(Parent.idKey == child[keyPath: parentIDKey])
    }

    /// Convenience for getting the parent.
    public func get(on executor: QueryExecutor) -> Future<Parent?> {
        return query(on: executor).first()
    }
}

// MARK: Model

extension Model {
    /// Create a children relation for this model.
    public func parent<P: Model>(
        idKey: Parent<Self, P>.ParentIDKey
    ) -> Parent<Self, P> {
        return Parent(
            child: self,
            idKey: idKey
        )
    }
}

