extension QueryRepresentable where Self: ExecutorRepresentable {
    /// Manually create and append filter
    @discardableResult
    public func filter(
        _ filter: Filter
    ) throws -> Query<Self.E> {
        let query = try makeQuery()
        query.filters.append(.some(filter))
        return query
    }

    /// Filter entity with field, comparison, and value.
    @discardableResult
    public func filter<T: Entity>(
        _ entity: T.Type,
        _ field: String,
        _ comparison: Filter.Comparison,
        _ value: NodeRepresentable?
    ) throws -> Query<Self.E> {
        let query = try makeQuery()
        let value = try value?.makeNode(in: query.context) ?? .null
        let filter = Filter(entity, .compare(field, comparison, value))
        return try query.filter(filter)
    }

    /// Filter entity where field equals value
    @discardableResult
    public func filter<T: Entity>(
        _ entity: T.Type,
        _ field: String,
        _ value: NodeRepresentable?
    ) throws -> Query<Self.E> {
        return try makeQuery()
            .filter(entity, field, .equals, value)
    }

    /// Filter self with field, comparison, and value.
    @discardableResult
    public func filter(
        _ field: String,
        _ comparison: Filter.Comparison,
        _ value: NodeRepresentable?
    ) throws -> Query<Self.E> {
        return try makeQuery()
            .filter(E.self, field, comparison, value)
    }

    /// Filter self where field equals value.
    @discardableResult
    public func filter(
        _ field: String,
        _ value: NodeRepresentable?
    ) throws -> Query<Self.E> {
        return try makeQuery()
            .filter(field, .equals, value)
    }

    /// Entity operator filter queries
    @discardableResult
    public func filter<T: Entity>(
        _ entity: T.Type,
        _ value: Filter.Method
    ) throws -> Query<Self.E> {
        let filter = Filter(T.self, value)
        return try makeQuery().filter(filter)
    }

    /// Self operator filter queries
    @discardableResult
    public func filter(
        _ value: Filter.Method
    ) throws -> Query<Self.E> {
        let filter = Filter(E.self, value)
        return try makeQuery().filter(filter)
    }


    /// Subset `in` filter.
    @discardableResult
    public func filter(_ field: String, in values: [NodeRepresentable?]) throws -> Query<Self.E> {
        let values = try values.map { try $0.makeNode(in: Row.defaultContext) }
        let method = Filter.Method.subset(field, .in, values)
        let filter = Filter(E.self, method)
        return try makeQuery().filter(filter)
    }

    /// Subset `notIn` filter. 
    @discardableResult
    public func filter(_ field: String, notIn values: [NodeRepresentable?]) throws -> Query<Self.E> {
        let values = try values.map { try $0.makeNode(in: Row.defaultContext) }
        let method = Filter.Method.subset(field, .notIn, values)
        let filter = Filter(E.self, method)
        return try makeQuery().filter(filter)
    }
}
