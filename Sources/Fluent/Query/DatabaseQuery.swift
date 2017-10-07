public struct DatabaseQuery {
    /// The entity to query
    public let entity: String

    /// The action to perform on the database
    public var action: Action

    /// Result stream will be filtered by these queries.
    public var filters: [Filter]

    /// If true, the query will only select distinct rows.
    public var isDistinct: Bool

    /// Optional model data to save or update.
    public var data: Encodable?

    /// Create a new database query.
    public init(entity: String) {
        self.entity = entity
        self.action = .fetch
        self.filters = []
        self.isDistinct = false
        self.data = nil
    }
}
