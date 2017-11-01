public struct Predicate {
    public var column: DataColumn
    public var comparison: PredicateComparison
    public var value: PredicateValue

    public init(
        column: DataColumn,
        comparison: PredicateComparison,
        value: PredicateValue
    ) {
        self.column = column
        self.comparison = comparison
        self.value = value
    }
}

public enum PredicateValue {
    case placeholder
    case column(DataColumn)
}
