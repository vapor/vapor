/// A query that can be sent to a Fluent database.
public struct DatabaseQuery {
    /// The entity to query
    public let entity: String

    /// The action to perform on the database
    public var action: QueryAction

    /// Result stream will be filtered by these queries.
    public var filters: [QueryFilter]

    /// Sorts to be applied to the results.
    public var sorts: [QuerySort]

    /// Aggregates / computed methods.
    public var aggregates: [QueryAggregate]

    /// If true, the query will only select distinct rows.
    public var isDistinct: Bool

    /// Optional model data to save or update.
    public var data: Encodable?

    /// Limits and offsets the amount of results
    public var range: QueryRange?

    /// Allows extensions to store properties.
    public var extend: [String: Any]

    /// Create a new database query.
    public init(entity: String) {
        self.entity = entity
        self.action = .read
        self.filters = []
        self.sorts = []
        self.aggregates = []
        self.isDistinct = false
        self.data = nil
        self.range = nil
        self.extend = [:]
    }
}
