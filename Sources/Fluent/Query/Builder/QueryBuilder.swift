import Async
import Foundation

/// A Fluent database query builder.
public final class QueryBuilder<Model> where Model: Fluent.Model {
    /// The query we are building
    public var query: DatabaseQuery

    /// The connection this query will be excuted on.
    /// note: don't call execute manually or fluent's
    /// hooks will not run properly.
    internal let connection: Future<Model.Database.Connection>

    /// Create a new query.
    public init(
        _ model: Model.Type = Model.self,
        on connection: Future<Model.Database.Connection>
    ) {
        query = DatabaseQuery(entity: Model.entity)
        self.connection = connection
    }

    /// Creates a result stream.
    public func run<D>(decoding type: D.Type) -> QueryResultStream<D, Model.Database> where D: Decodable {
        /// if the model is soft deletable, and soft deleted
        /// models were not requested, then exclude them
        if
            let type = Model.self as? AnySoftDeletable.Type,
            !self.query.withSoftDeleted
        {
            guard let deletedAtKey = type.keyStringMap[type.anyDeletedAtKey] else {
                fatalError("no key")
            }

            let deletedAtField = QueryField(entity: type.entity, name: deletedAtKey)

            try! self.group(.or) { or in
                try or.filter(deletedAtField > Date())
                try or.filter(deletedAtField == Date.null)
            }
        }

        return QueryResultStream(query: query, on: connection)
    }

    /// Convenience run that defaults to outputting a
    /// stream of the QueryBuilder's model type.
    /// Note: this also sets the model's ID if the ID
    /// type is autoincrement.
    public func run() -> QueryResultStream<Model, Model.Database> {
        let stream = self.run(decoding: Model.self)

        stream.outputMap = { output, conn in
            switch self.query.action {
            case .create:
                try output.parseID(from: conn)
            default: break
            }
            return output
        }

        return stream
    }

    // Create a new query build w/ same connection.
    internal func copy() -> QueryBuilder<Model> {
        return QueryBuilder(on: connection)
    }
}

extension Model {
    /// Sets the model's id from the connection if it is
    /// of type autoincrementing
    internal func parseID(from conn: Database.Connection) throws {
        guard fluentID == nil, case .autoincrementing(let convert) = ID.identifierType else {
            return
        }

        guard let lastID = conn.lastAutoincrementID else {
            throw FluentError(
                identifier: "noAutoincrementID",
                reason: "No auto increment ID was returned by the database when decoding \(Self.name) models"
            )
        }

        fluentID = convert(lastID)
    }
}
