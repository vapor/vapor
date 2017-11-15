import Fluent
import SQL

extension QuerySort {
    /// Convert query sort to sql order by.
    internal func makeDataOrderBy() -> DataOrderBy {
        return DataOrderBy(
            columns: [field.makeDataColumn()],
            direction: direction.makeOrderByDirection()
        )
    }
}

extension QuerySortDirection {
    /// Convert query sort direction to sql order by direction.
    internal func makeOrderByDirection() -> OrderByDirection {
        switch self {
        case .ascending: return .ascending
        case .descending: return .descending
        }
    }
}
