import Fluent
import SQL

extension QueryFilter {
    /// Convert query filter to sql data predicate and bind values.
    internal func makeDataPredicateItem() -> (DataPredicateItem, [BindValue]) {
        let item: DataPredicateItem
        var values: [BindValue] = []

        switch method {
        case .compare(let field, let comp, let value):
            let predicate = DataPredicate(
                column: field.makeDataColumn(),
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
                column: field.makeDataColumn(),
                comparison: scope.makeDataPredicateComparison(),
                value: predicateValue
            )

            values += binds

            item = .predicate(predicate)
        }

        return (item, values)
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
