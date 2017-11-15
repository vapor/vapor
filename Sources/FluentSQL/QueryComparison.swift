import Fluent
import SQL

extension QueryComparison {
    /// Convert query comparison to sql predicate comparison.
    internal func makeDataPredicateComparison() -> DataPredicateComparison {
        switch self {
        case .equality(let eq): return eq.makeDataPredicateComparison()
        case .order(let or): return or.makeDataPredicateComparison()
        case .sequence(let seq): return seq.makeDataPredicateComparison()
        }
    }
}

extension QueryComparisonValue {
    /// Convert query comparison value to sql data predicate value.
    internal func makeDataPredicateValue() -> DataPredicateValue {
        switch self {
        case .field(let field):
            return .column(field.makeDataColumn())
        case .value:
            return .placeholder
        }
    }
}

extension EqualityComparison {
    /// Convert query comparison to sql predicate comparison.
    internal func makeDataPredicateComparison() -> DataPredicateComparison {
        switch self {
        case .equals: return .equal
        case .notEquals: return .notEqual
        }
    }
}

extension OrderedComparison {
    /// Convert query comparison to sql predicate comparison.
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
    /// Convert query comparison to sql predicate comparison.
    internal func makeDataPredicateComparison() -> DataPredicateComparison {
        switch self {
        case .hasPrefix: return .like
        case .hasSuffix: return .like
        case .contains: return .like
        }
    }
}

extension SequenceComparison {
    /// Convert sequence comparison to bind wildcard.
    internal func makeBindWildcard() -> BindWildcard {
        switch self {
        case .contains: return .fullWildcard
        case .hasPrefix: return .trailingWildcard
        case .hasSuffix: return .leadingWildcard
        }
    }
}

