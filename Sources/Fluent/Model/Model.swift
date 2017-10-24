import Async

/// Fluent database models. These types can be fetched
/// from a database connection using a query.
///
/// Types conforming to this protocol provide the basis
/// fetching and saving data to/from Fluent.
public protocol Model: Codable {
    associatedtype I: Identifier

    /// This model's collection/table name
    static var entity: String { get }

    /// The model's identifier.
    var id: I? { get set }
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
    public mutating func save(to executor: QueryExecutor, new: Bool = false) -> Future<Void> {
        let query = executor.query(Self.self)
        query.query.data = self
        
        if let id = self.id, !new {
            query.filter("id" == id)
            // update record w/ matching id
            query.query.action = .update
        } else if id == nil {
            switch I.identifierType {
            case .autoincrementing: break
            case .generated(let factory):
                id = factory()
            case .supplied: break
                // FIXME: error if not actually supplied?
            }
            // create w/ generated id
            query.query.action = .create
        } else {
            // just create, with existing id
            query.query.action = .create
        }

        return query.run()
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
