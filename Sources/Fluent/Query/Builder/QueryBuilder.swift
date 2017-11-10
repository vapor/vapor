import Async
import Foundation

/// A Fluent database query builder.
public final class QueryBuilder<Model: Fluent.Model> {
    /// The query we are building
    public var query: DatabaseQuery

    /// The connection this query will be excuted on.
    /// note: this must be private to ensure we have one
    /// place where queries can be executed so we can apply
    /// filters like soft deletable.
    private let connection: Model.Database.Connection

    /// Create a new query.
    public init(
        _ model: Model.Type = Model.self,
        on connection: Model.Database.Connection
    ) {
        query = DatabaseQuery(entity: Model.entity)
        self.connection = connection
    }

    /// Begins executing the connection and sending
    /// results to the output stream.
    /// The resulting future will be completed when the
    /// query is done or fails
    public func run<T: Decodable>(
        decoding type: T.Type = T.self,
        into outputStream: @escaping BasicStream<T>.OutputHandler
    ) -> Future<Void> {
        return then {
            let promise = Promise(Void.self)
            let stream = BasicStream<T>()

            /// if the model is soft deletable, and soft deleted
            /// models were not requested, then exclude them
            if Model.self is SoftDeletable, !self.query.withSoftDeleted {
                // FIXME: DeletedAtKey
                try self.group(.or) { or in
                    try or.filter("deletedAt" > Date())
                    try or.filter("deletedAt" == Date.null)
                }
            }

            // connect output
            stream.outputStream = outputStream

            // connect close
            stream.onClose = {
                promise.complete()
            }

            // connect error
            stream.errorStream = { error in
                promise.fail(error)
            }

            // execute
            // note: this must be in this file to access connection!
            self.connection.execute(query: self.query, into: stream)

            return promise.future
        }
    }

    // Create a new query build w/ same connection.
    internal func copy() -> QueryBuilder<Model> {
        return QueryBuilder(on: connection)
    }
}
