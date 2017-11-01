import Fluent
import SQL

extension DatabaseQuery {
    public func makeDataQuery() -> DataQuery {
        return DataQuery(
            statement: action.makeDataStatement(),
            table: entity,
            columns: [],
            computed: [], // FIXME: aggregate
            joins: [],
            predicates: [],
            orderBys: [],
            limit: nil,
            offset: nil
        )
    }
}

extension QueryAction {
    public func makeDataStatement() -> DataStatement {
        switch self {
        case .create: return .insert
        case .read: return .select
        case .update: return .update
        case .delete: return .delete
        case .aggregate: return .select
        }
    }
}

extension QueryAggregate {
    var function: String {
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
    fileprivate var dataColumn: DataColumn {
        return DataColumn(table: entity, name: name)
    }
}

extension ComparisonValue {
    fileprivate var predicateValue: PredicateValue {
        switch self {
        case .field(let field):
            return .column(field.dataColumn)
        case .value:
            return .placeholder
        }
    }
}

extension Filter {
    fileprivate func makePredicate() throws -> (predicate: Predicate, value: SQLiteData?) {
        let predicate: Predicate
        let data: SQLiteData?

        switch method {
        case .equality(let field, let comp, let value):
            predicate = Predicate(
                column: field.dataColumn,
                comparison: comp.predicate,
                value: value.predicateValue
            )

            if case .value(let encodable) = value {
                let encoder = SQLiteDataEncoder()
                try encodable.encode(to: encoder)
                data = encoder.data
            } else {
                data = nil
            }

//            switch comp {
//            case .hasPrefix:
//                value = .text((encoder.data.text ?? "") + "%")
//            case .hasSuffix:
//                value = .text("%" + (encoder.data.text ?? ""))
//            case .contains:
//                value = .text("%" + (encoder.data.text ?? "") + "%")
//            default:
//            }
        default:
            fatalError("not implemented")
        }

        return (predicate, data)
    }
}

extension Join {
    fileprivate var join: SQL.Join {
        return .init(
            method: type.method,
            table: baseEntity,
            column: baseKey,
            foreignTable: joinedEntity,
            foreignColumn: joinedKey
        )
    }
}

extension JoinType {
    fileprivate var method: SQL.JoinMethod {
        switch self {
        case .inner: return .inner
        case .outer: return .outer
        }
    }
}

extension QuerySort {
    fileprivate var orderBy: OrderBy {
        return OrderBy(
            columns: [DataColumn(table: entity, name: field)],
            direction: direction.orderByDirection
        )
    }
}

extension QuerySortDirection {
    fileprivate var orderByDirection: OrderByDirection {
        switch self {
        case .ascending: return .ascending
        case .descending: return .descending
        }
    }
}

extension EqualityComparison {
    var predicate: PredicateComparison {
        switch self {
        case .equals: return .equal
        case .notEquals: return .notEqual
        }
    }
}

extension OrderedComparison {
    var predicate: PredicateComparison {
        switch self {
        case .greaterThan: return .greaterThan
        case .greaterThanOrEquals: return .greaterThanOrEqual
        case .lessThan: return .lessThan
        case .lessThanOrEquals: return .lessThanOrEqual
        }
    }
}

extension SequenceComparison {
    var predicate: PredicateComparison {
        switch self {
        case .hasPrefix: return .like
        case .hasSuffix: return .like
        case .contains: return .like
        }
    }
}
