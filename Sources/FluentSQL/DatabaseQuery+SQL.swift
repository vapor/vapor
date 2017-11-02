import Fluent
import SQL

public struct BindValue {
    public var encodable: Encodable
    public var method: BindValueMethod
}

public enum BindValueMethod {
    case plain
    case wildcard(BindWildcard)
}

public enum BindWildcard {
    case leadingWildcard // %s
    case trailingWildcard // s%
    case fullWildcard // %s%
}

extension DatabaseQuery {
    /// Create a SQL query from this database query.
    /// All Encodable values found while converting the query
    /// will be returned in an array in the order that placeholders
    /// will appear in the serialized SQL query.
    public func makeDataQuery() -> (DataQuery, [BindValue]) {
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
            columns: [],
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

// MARK: Internal

extension QuerySort {
    internal func makeDataOrderBy() -> DataOrderBy {
        return DataOrderBy(
            columns: [field.makeDataColumn()],
            direction: direction.makeOrderByDirection()
        )
    }
}

extension QuerySortDirection {
    internal func makeOrderByDirection() -> OrderByDirection {
        switch self {
        case .ascending: return .ascending
        case .descending: return .descending
        }
    }
}

extension QueryAction {
    internal func makeDataStatement() -> DataStatement {
        switch self {
        case .create: return .insert
        case .read: return .select
        case .update: return .update
        case .delete: return .delete
        case .aggregate: return .select
        }
    }
}

extension QueryField {
    internal func makeDataColumn() -> DataColumn {
        return DataColumn(table: entity, name: name)
    }
}

extension QueryAggregate {
    internal func makeDataComputed() -> DataComputed {
        return DataComputed(
            function: method.makeDataComputedFunction(),
            columns: field.flatMap { [ $0.makeDataColumn() ] } ?? [],
            key: "fluentAggregate"
        )
    }
}

extension QueryAggregateMethod {
    internal func makeDataComputedFunction() -> String {
        switch self {
        case .count: return "count"
        case .sum: return "sum"
        case .custom(let s): return s
        case .average: return "avg"
        case .min: return "min"
        case .max: return "max"
        }
    }
}

extension QueryField {
    internal var dataColumn: DataColumn {
        return DataColumn(table: entity, name: name)
    }
}

extension QueryComparisonValue {
    internal func makeDataPredicateValue() -> DataPredicateValue {
        switch self {
        case .field(let field):
            return .column(field.dataColumn)
        case .value:
            return .placeholder
        }
    }
}

extension QuerySubsetScope {
    internal func makeDataPredicateComparison() -> DataPredicateComparison {
        switch self {
        case .in: return .in
        case .notIn: return .notIn
        }
    }
}

extension SequenceComparison {
    internal func makeBindWildcard() -> BindWildcard {
        switch self {
        case .contains: return .fullWildcard
        case .hasPrefix: return .trailingWildcard
        case .hasSuffix: return .leadingWildcard
        }
    }
}

extension QueryFilter {
    internal func makeDataPredicateItem() -> (DataPredicateItem, [BindValue]) {
        let item: DataPredicateItem
        var values: [BindValue] = []

        switch method {
        case .compare(let field, let comp, let value):
            let predicate = DataPredicate(
                column: field.dataColumn,
                comparison: comp.makeDataPredicateComparison(),
                value: value.makeDataPredicateValue()
            )

            if case .value(let encodable) = value {
                let method: BindValueMethod
                switch comp {
                case .sequence(let seq):
                    method = .wildcard(seq.makeBindWildcard())
                default:
                    method = .plain
                }

                let value = BindValue(encodable: encodable, method: method)
                values.append(value)
            }

            item = .predicate(predicate)
        case .group(let relation, let filters):
            let group = DataPredicateGroup(
                relation: relation.makeDataPredicateGroupRelation(),
                predicates: filters.map { filter in
                    let (predicate, newValues) = filter.makeDataPredicateItem()
                    values += newValues
                    return predicate
                }
            )

            item = .group(group)
        case .subset(let field, let scope, let value):
            let (predicateValue, binds) = value.makeDataPredicateValue()
            let predicate = DataPredicate(
                column: field.dataColumn,
                comparison: scope.makeDataPredicateComparison(),
                value: predicateValue
            )

            values += binds

            item = .predicate(predicate)
        }

        return (item, values)
    }
}

extension QuerySubsetValue {
    internal func makeDataPredicateValue() -> (DataPredicateValue, [BindValue]) {
        switch self {
        case .array(let array):
            let values = array.map { BindValue.init(encodable: $0, method: .plain) }
            return (.placeholderArray(array.count), values)
        case .subquery(let subquery):
            let (dataQuery, values) = subquery.makeDataQuery()
            return (.subquery(dataQuery), values)
        }
    }
}

extension QueryGroupRelation {
    internal func makeDataPredicateGroupRelation() -> DataPredicateGroupRelation {
        switch self {
        case .and: return .and
        case .or: return .or
        }
    }
}

extension QueryJoin {
    internal func makeDataJoin() -> DataJoin {
        return .init(
            method: method.makeDataJoinMethod(),
            table: baseEntity,
            column: baseKey,
            foreignTable: joinedEntity,
            foreignColumn: joinedKey
        )
    }
}

extension QueryJoinMethod {
    internal func makeDataJoinMethod() -> DataJoinMethod {
        switch self {
        case .inner: return .inner
        case .outer: return .outer
        }
    }
}

extension QueryComparison {
    internal func makeDataPredicateComparison() -> DataPredicateComparison {
        switch self {
        case .equality(let eq): return eq.makeDataPredicateComparison()
        case .order(let or): return or.makeDataPredicateComparison()
        case .sequence(let seq): return seq.makeDataPredicateComparison()
        }
    }
}


extension EqualityComparison {
    internal func makeDataPredicateComparison() -> DataPredicateComparison {
        switch self {
        case .equals: return .equal
        case .notEquals: return .notEqual
        }
    }
}

extension OrderedComparison {
    internal func makeDataPredicateComparison() -> DataPredicateComparison {
        switch self {
        case .greaterThan: return .greaterThan
        case .greaterThanOrEquals: return .greaterThanOrEqual
        case .lessThan: return .lessThan
        case .lessThanOrEquals: return .lessThanOrEqual
        }
    }
}

extension SequenceComparison {
    internal func makeDataPredicateComparison() -> DataPredicateComparison {
        switch self {
        case .hasPrefix: return .like
        case .hasSuffix: return .like
        case .contains: return .like
        }
    }
}
