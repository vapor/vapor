/// Defines a Fluent query limit and offset.
public struct QueryRange {
    /// The lower bound of item indexes to return.
    /// This should be 0 by default.
    public var lower: Int

    /// The upper bound of item indexes to return.
    /// If this is nil, the range acts as just on offset.
    /// If it is set, the number of results will have a max
    /// possible value.
    public var upper: Int?

    /// Creates a new limit with a count and offset.
    /// See Limit.count and Limit.offset.
    public init(lower: Int, upper: Int?) {
        self.lower = lower
        self.upper = upper
    }
}

extension QueryBuilder {
    /// Limits the query to a range of indexes.
    public func range(_ range: Range<Int>) -> Self {
        return self.range(lower: range.lowerBound, upper: range.upperBound)
    }

    /// Limits the query to a max number of results.
    public func range(_ range: PartialRangeThrough<Int>) -> Self {
        return self.range(upper: range.upperBound)
    }

    /// Limits the query to a max number of results.
    public func range(_ range: PartialRangeUpTo<Int>) -> Self {
        return self.range(upper: range.upperBound - 1)
    }

    /// Offsets the query by the supplied index.
    public func range(_ range: PartialRangeFrom<Int>) -> Self {
        return self.range(lower: range.lowerBound)
    }

    /// Convenience for applying a range to the query.
    public func range(lower: Int = 0, upper: Int? = nil) -> Self {
        let limit = QueryRange(lower: lower, upper: upper)
        query.range = limit
        return self
    }
}
