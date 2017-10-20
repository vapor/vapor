import Async

/// Fluent database models. These types can be fetched
/// from a database connection using a query.
///
/// Types conforming to this protocol provide the basis
/// fetching and saving data to/from Fluent.
public protocol Model: Codable {
    associatedtype Identifier: Codable

    /// This model's collection/table name
    static var entity: String { get }

    /// The model's identifier.
    var id: Identifier? { get set }

    /// Stores crucial state info on the model.
    var storage: Storage { get }
}

/// Free implementations.
extension Model {
    /// See Model.entity
    public static var entity: String {
        return "\(Self.self)".lowercased() + "s"
    }
}

// MARK: CRUD

extension Model {
    public func save(to executor: QueryExecutor) -> Future<Void> {
        let query = executor.query(Self.self)
        query.query.data = self
        if exists {
            query.query.action = .update
            query.filter("id" == id)
        } else {
            query.query.action = .create
        }
        return executor.execute(query: query.query, into: BasicStream<Self>())
    }
}

// MARK: Convenience
extension Model {
    /// Create a query for this model type on the supplied connection.
    public static func makeQuery<Self>(on conn: DatabaseConnection) -> QueryBuilder<Self> {
        return QueryBuilder(on: conn)
    }

    /// Create a query for this model instance on the supplied connection.
    public func makeQuery(on conn: DatabaseConnection) -> QueryBuilder<Self> {
        let builder = QueryBuilder<Self>(on: conn)
        builder.query.data = self
        return builder
    }
}
