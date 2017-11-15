public struct DataPredicate {
    public var column: DataColumn
    public var comparison: DataPredicateComparison
    public var value: DataPredicateValue

    public init(
        column: DataColumn,
        comparison: DataPredicateComparison,
        value: DataPredicateValue
    ) {
        self.column = column
        self.comparison = comparison
        self.value = value
    }
}

public enum DataPredicateValue {
    case none
    case placeholder
    case placeholderArray(Int)
    case column(DataColumn)
    case subquery(DataQuery)
}
