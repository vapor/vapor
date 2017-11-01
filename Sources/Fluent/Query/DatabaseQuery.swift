/// A query that can be sent to a Fluent database.
public struct DatabaseQuery {
    /// The entity to query
    public let entity: String

    /// The action to perform on the database
    public var action: QueryAction

    /// Result stream will be filtered by these queries.
    public var filters: [Filter]

    /// Joined models.
    public var joins: [Join]

    /// If true, the query will only select distinct rows.
    public var isDistinct: Bool

    /// Optional model data to save or update.
    public var data: Encodable?

    /// Limits and offsets the amount of results
    public var limit: Limit?

    /// Create a new database query.
    public init(entity: String) {
        self.entity = entity
        self.action = .read
        self.filters = []
        self.joins = []
        self.isDistinct = false
        self.data = nil
        self.limit = nil
    }
}
