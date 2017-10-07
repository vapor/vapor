public enum PredicateComparison {
    case equal
    case notEqual
    case lessThan
    case greaterThan
    case lessThanOrEqual
    case greaterThanOrEqual
    case `in`(sub: DataQuery)
    case notIn(sub: DataQuery)
    case between
    case like
    case notLike
    case null
    case notNull
}
