import Fluent
import SQL

extension QueryJoin {
    /// Convert query join to sql join
    internal func makeDataJoin() -> DataJoin {
        return .init(
            method: method.makeDataJoinMethod(),
            table: baseEntity,
            column: baseKey,
            foreignTable: joinedEntity,
            foreignColumn: joinedKey
        )
    }
}

extension QueryJoinMethod {
    /// Convert query join method to sql join method
    internal func makeDataJoinMethod() -> DataJoinMethod {
        switch self {
        case .inner: return .inner
        case .outer: return .outer
        }
    }
}

