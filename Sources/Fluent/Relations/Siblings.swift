public struct Siblings<From: Model, To: Model, Through: Pivot> {
    /// The base model which all fetched models
    /// should be related to.
    public let from: From

    /// Create a new Siblings relation.
    public init(
        from: From,
        to: To.Type = To.self,
        through: Through.Type = Through.self
    ) {
        self.from = from
    }

    /// Create a query for the parent.
    public func query(on executor: QueryExecutor) -> QueryBuilder<To> {
        let builder = executor.query(To.self)
        // FIXME: join pivot
        return builder
    }
}

// MARK: Model

extension Model {
    /// Create a siblings relation for this model.
    public func siblings<To: Model, Through: Pivot>(
        to: To.Type = To.self,
        through: Through.Type = Through.self
    ) -> Siblings<Self, To, Through> {
        return Siblings(from: self)
    }
}
