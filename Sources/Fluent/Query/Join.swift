/// Describes a relational join which brings
/// columns of data from multiplies entities
/// into one response.
///
/// A = (id, name, b_id)
/// B = (id, foo)
///
/// A join B = (id, b_id, name, foo)
///
/// foreignKey = A.b_id
/// localKey = B.id
public struct Join {
    /// Entity that will be accepting
    /// the joined data
    public let base: Model.Type

    /// Entity that will be joining
    /// the base data
    public let joined: Model.Type
    
    /// An exhaustive list of 
    /// possible join types.
    public enum Kind {
        /// returns only rows that
        /// appear in both sets
        case inner
        /// returns all matching rows
        /// from the queried table _and_
        /// all rows that appear in both sets
        case outer
    }

    public let kind: Kind

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
        kind: Kind,
        base: Base.Type,
        joined: Joined.Type,
        baseKey: String = Base.idKey,
        joinedKey: String = Base.foreignIdKey
    ) {
        self.kind = kind
        self.base = base
        self.joined = joined
        self.baseKey = baseKey
        self.joinedKey = joinedKey
    }
}

extension QueryRepresentable where Self: ExecutorRepresentable {
    /// Create and add a Join to this Query.
    /// See Join for more information.
    @discardableResult
    public func join<Joined: Model>(
        kind: Join.Kind = .inner,
        _ joined: Joined.Type,
        baseKey: String = E.idKey,
        joinedKey: String = E.foreignIdKey
    ) throws -> Query<Self.E> {
        let join = Join(
            kind: kind,
            base: E.self,
            joined: joined,
            baseKey: baseKey,
            joinedKey: joinedKey
        )

        return try self.join(join)
    }


    @discardableResult
    public func join(_ join: Join) throws -> Query<Self.E> {
        let query = try makeQuery()
        query.joins.append(.some(join))
        return query
    }
}
