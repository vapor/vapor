/// Describes a relational join which brings
/// columns of data from multiple entities
/// into one response.
///
/// A = (id, name, b_id)
/// B = (id, foo)
///
/// A join B = (id, b_id, name, foo)
///
/// joinedKey = A.b_id
/// baseKey = B.id
public struct QueryJoin {
    /// table/collection that will be
    /// accepting the joined data
    public let baseEntity: String

    /// table/collection that will be
    /// joining the base data
    public let joinedEntity: String

    /// Join type.
    /// See QueryJoinMethod.
    public let method: QueryJoinMethod

    /// The key from the base table that will
    /// be compared to the key from the joined
    /// table during the join.
    ///
    /// base        | joined
    /// ------------+-------
    /// <baseKey>   | base_id
    public let baseKey: String

    /// The key from the joined table that will
    /// be compared to the key from the base
    /// table during the join.
    ///
    /// base | joined
    /// -----+-------
    /// id   | <joined_key>
    public let joinedKey: String

    /// Create a new Join
    public init<Base: Model, Joined: Model>(
        method: QueryJoinMethod,
        base: Base.Type = Base.self,
        joined: Joined.Type = Joined.self,
        baseKey: String = Base.idKey,
        joinedKey: String = Base.foreignIDKey
    ) {
        self.method = method
        self.baseEntity = base.entity
        self.joinedEntity = joined.entity
        self.baseKey = baseKey
        self.joinedKey = joinedKey
    }
}

/// An exhaustive list of
/// possible join types.
public enum QueryJoinMethod {
    /// returns only rows that
    /// appear in both sets
    case inner
    /// returns all matching rows
    /// from the queried table _and_
    /// all rows that appear in both sets
    case outer
}

extension QueryBuilder {
    /// Join another model to this query builder.
    public func join<Joined: Model>(
        _ model: Joined.Type,
        method: QueryJoinMethod = .inner,
        baseKey: String = M.idKey,
        joinedKey: String = M.foreignIDKey
    ) -> Self {
        let join = QueryJoin(
            method: method,
            base: M.self,
            joined: Joined.self,
            baseKey: baseKey,
            joinedKey: joinedKey
        )
        query.joins.append(join)
        return self
    }
}
