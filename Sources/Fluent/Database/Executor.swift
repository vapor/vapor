/// An Executor is any entity that can execute
/// the queries for retreiving/sending data and
/// building databases that Fluent relies on.
///
/// Executors may include varying layers of
/// performance optimizations such as connection
/// and thread pooling.
///
/// The lowest level executor is usually a connection
/// while the highest level executor can have many
/// layers of abstraction on top of the connection
/// for performance and convenience.
public protocol Executor {
    /// Executes a `Query` from and
    /// returns an array of results fetched,
    /// created, or updated by the action.
    ///
    /// Drivers that support raw querying
    /// accept string queries and parameterized values.
    ///
    /// This allows Fluent extensions to be written that
    /// can support custom querying behavior.
    ///
    /// - note: Passing parameterized values as a `[Node]` array
    ///         instead of interpolating them into the raw string
    ///         can help prevent SQL injection.
    @discardableResult
    func query<M, D: Decodable>(_ query: RawOr<Query<M>>) throws -> D
    
    // Any queries executed by this executor
    // should be logged to the query logger
    var queryLogger: QueryLogger? { get set }
}

// MARK: Convenience

extension Executor {
    @discardableResult
    public func raw<D: Decodable>(_ raw: String, _ values: [Encodable] = []) throws -> D {
        return try self.query(RawOr<Query<Raw>>.raw(raw, values))
    }
    
    @discardableResult
    public func query<E, D: Decodable>(_ query: Query<E>) throws -> D {
        return try self.query(.some(query))
    }
}
