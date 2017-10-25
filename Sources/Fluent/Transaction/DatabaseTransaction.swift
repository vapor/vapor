import Async

/// A database transaction. Work done inside the
/// transaction's closure will be rolled back if
/// any errors are thrown.
public struct DatabaseTransaction {
    public typealias Closure = (QueryExecutor) -> Future<Void>
    public let closure: Closure
}
