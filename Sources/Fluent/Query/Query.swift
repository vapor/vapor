/// Represents an abstract database query.
public final class Query<E: Model> {
    /// The type of action to perform
    /// on the data. Defaults to `.fetch`
    public var action: Action

    /// An array of filters to apply
    ///during the query's action.
    public var filters: [RawOr<Filter>]

    /// Optional data to be used during
    ///`.create` or `.modify` actions.
    public var data: [RawOr<String>: RawOr<Encodable>]

    /// Optionally limit the amount of
    /// entities affected by the action.
    public var limits: [RawOr<Limit>]

    /// An array of sorts that will
    /// be applied to the results.
    public var sorts: [RawOr<Sort>]

    /// An array of joins: other entities
    /// that will be queried during this query's
    /// execution.
    public var joins: [RawOr<Join>]
    
    /// An optional entity used for delete
    /// and save queries
    public var entity: E?

    /// If true, soft deleted entities will be 
    /// included (given the Entity type is SoftDeletable)
    internal var includeSoftDeleted: Bool
    
    /// If true, uses appropriate distinct modifiers
    /// on fetch and counts to return only distinct
    /// results for this query.
    public var isDistinct: Bool

    /// Creates a new `Query` with the
    /// `Model`'s database.
    public init(_ executor: Executor) {
        filters = []
        action = .fetch(E.computedFields)
        self.executor = executor
        joins = []
        limits = []
        sorts = []
        isDistinct = false
        includeSoftDeleted = false
        data = [:]
    }
    
    /// Performs the Query returning the raw
    /// Node data from the driver.
    @discardableResult
    public func raw<D: Decodable>(_ type: D.Type = D.self) throws -> D {
        // if this is a soft deletable entity,
        // and soft deleted rows should not be included,
        // then filter them out
        if
            let S = E.self as? SoftDeletable.Type,
            !self.includeSoftDeleted
        {
            // require that all entities have deletedAt = null
            // or to some date in the future (not deleted yet)
            try self.or { subquery in
                try subquery.filter(S.deletedAtKey, Node.null)
                try subquery.filter(S.deletedAtKey, .greaterThan, Date())
            }
            
            let results = try executor.query(.some(self))
            
            // remove the soft delete filter
            _ = self.filters.popLast()
            
            return results
        } else {
            return try executor.query(.some(self))
        }
    }
    
    public let executor: Executor

    //MARK: Internal

    /// The database to which the query
    /// should be sent.
    // internal let database: Database
}

extension Query: QueryRepresentable, ExecutorRepresentable {
    /// Conformance to `QueryRepresentable`
    public func makeQuery(_ executor: Executor) -> Query<E> {
        return self
    }
    
    public func makeExecutor() -> Executor {
        return executor
    }
}
