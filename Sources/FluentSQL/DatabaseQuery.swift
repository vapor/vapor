import Fluent
import SQL

extension DatabaseQuery {
    /// Create a SQL query from this database query.
    /// All Encodable values found while converting the query
    /// will be returned in an array in the order that placeholders
    /// will appear in the serialized SQL query.
    public func makeDataQuery(columns: [DataColumn] = []) -> (DataQuery, [BindValue]) {
        var encodables: [BindValue] = []

        let limit: Int?
        if let upper = range?.upper, let lower = range?.lower {
            limit = upper - lower
        } else {
            limit = nil
        }

        let query = DataQuery(
            statement: action.makeDataStatement(),
            table: entity,
            columns: columns,
            computed: aggregates.map { $0.makeDataComputed() },
            joins: joins.map { $0.makeDataJoin() },
            predicates: filters.map { filter in
                let (predicate, values) = filter.makeDataPredicateItem()
                encodables += values
                return predicate
            },
            orderBys: sorts.map { $0.makeDataOrderBy() },
            limit: limit,
            offset: range?.lower
        )

        return (query, encodables)
    }
}
