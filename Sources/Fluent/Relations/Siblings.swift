public struct Siblings<From: Model, To: Model, Through: Pivot> {
    /// The base model which all fetched models
    /// should be related to.
    public let from: From

    /// The From model's foreign id key.
    /// This is usually From.foreignIDKey.
    /// note: This is used to filter the pivot.
    public let fromForeignIDKey: String

    /// The To model's foreign id key.
    /// This is usually To.foreignIDKey.
    /// note: This is used to join the pivot.
    public let toForeignIDKey: String

    /// Create a new Siblings relation.
    public init(
        from: From,
        to: To.Type = To.self,
        through: Through.Type = Through.self,
        fromForeignIDKey: String = From.foreignIDKey,
        toForeignIDKey: String = To.foreignIDKey
    ) {
        self.from = from
        self.fromForeignIDKey = fromForeignIDKey
        self.toForeignIDKey = toForeignIDKey
    }

    /// Create a query for the parent.
    public func query(on executor: QueryExecutor) -> QueryBuilder<To> {
        return executor.query(To.self)
            .join(Through.self, joinedKey: toForeignIDKey)
            .filter(Through.self, fromForeignIDKey == from.id)
    }
}

// MARK: Model

extension Model {
    /// Create a siblings relation for this model.
    public func siblings<To: Model, Through: Pivot>(
        to: To.Type = To.self,
        through: Through.Type = Through.self,
        fromForeignIDKey: String = Self.foreignIDKey,
        toForeignIDKey: String = To.foreignIDKey
    ) -> Siblings<Self, To, Through> {
        return Siblings(
            from: self,
            fromForeignIDKey: fromForeignIDKey,
            toForeignIDKey: toForeignIDKey
        )
    }
}
