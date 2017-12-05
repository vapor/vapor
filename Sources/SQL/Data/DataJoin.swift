/// Represents a SQL join.
public struct DataJoin {
    public let method: DataJoinMethod
    public let local: DataColumn
    public let foreign: DataColumn

    /// Create a new SQL join.
    public init(
        method: DataJoinMethod,
        local: DataColumn,
        foreign: DataColumn
    ) {
        self.method = method
        self.local = local
        self.foreign = foreign
    }
}
