import Fluent
import SQL

extension QueryAction {
    /// Convert query action to data statement.
    internal func makeDataStatement() -> DataStatement {
        switch self {
        case .create: return .insert
        case .read: return .select
        case .update: return .update
        case .delete: return .delete
        case .aggregate: return .select
        }
    }
}
