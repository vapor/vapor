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
    func query<E>(_ query: RawOr<Query<E>>) throws -> Node
    
    // Any queries executed by this executor
    // should be logged to the query logger
    var queryLogger: QueryLogger? { get set }
}

// MARK: Convenience

extension Executor {
    @discardableResult
    public func raw(_ raw: String, _ values: [NodeRepresentable] = []) throws -> Node {
        let nodes = try values.map { try $0.makeNode(in: rowContext) }
        return try self.query(RawOr<Query<Raw>>.raw(raw, nodes))
    }
    
    @discardableResult
    public func query<E>(_ query: Query<E>) throws -> Node {
        return try self.query(.some(query))
    }
}
