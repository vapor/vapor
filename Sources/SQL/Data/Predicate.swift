public struct Predicate {
    public let table: String?
    public let column: String
    public let comparison: PredicateComparison

    public init(
        table: String? = nil,
        column: String,
        comparison: PredicateComparison
    ) {
        self.table = table
        self.column = column
        self.comparison = comparison
    }
}
